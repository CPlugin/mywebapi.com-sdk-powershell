function Invoke-MyWebApiRequest {
    # Single choke point for every REST cmdlet: auth, URL build, envelope unwrap, paging.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Method,
        [Parameter(Mandatory)][string] $Path,
        [hashtable] $Query,
        [object]    $Body,
        [string]    $TradePlatform,
        [Nullable[guid]] $CacheId,
        [int]       $CacheTimeout,
        [string]    $IdempotencyKey,
        [switch]    $All
    )

    if (-not $script:MyWebApiContext) { throw 'Not connected. Call Connect-MyWebApi first.' }
    $ctx = $script:MyWebApiContext

    # * Safe property read for the v2 envelope. Under `Set-StrictMode -Version Latest`
    #   a direct `$resp.error` throws PropertyNotFoundException when the server OMITS
    #   a null field (e.g. success responses carry no `error` key). Reading via
    #   PSObject.Properties returns $null for an absent property instead of throwing.
    function Get-EnvProp($obj, $name) {
        if ($null -eq $obj) { return $null }
        $p = $obj.PSObject.Properties[$name]
        if ($p) { return $p.Value }
        return $null
    }

    # Resolve {tradePlatform} from arg or session default.
    if ($Path -like '*{tradePlatform}*') {
        $tp = if ($TradePlatform) { $TradePlatform } else { $ctx.DefaultTradePlatform }
        if (-not $tp) { throw 'No trade platform: pass -TradePlatform or set -DefaultTradePlatform on Connect-MyWebApi.' }
        $Path = $Path.Replace('{tradePlatform}', [uri]::EscapeDataString($tp))
    }

    $token = Get-MyWebApiToken
    $headers = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
    if ($IdempotencyKey) { $headers['Idempotency-Key'] = $IdempotencyKey }

    $q = @{}
    if ($Query) { foreach ($k in $Query.Keys) { if ($null -ne $Query[$k]) { $q[$k] = $Query[$k] } } }
    if ($CacheId)      { $q['cacheId']      = $CacheId.ToString() }
    if ($CacheTimeout) { $q['cacheTimeout'] = $CacheTimeout }

    $accumulated = [System.Collections.Generic.List[object]]::new()
    $cursor = $null

    do {
        if ($All -and $cursor) { $q['cursor'] = $cursor }
        # * Array/collection query values (e.g. -Logins 1,2) must serialize as repeated keys
        #   (logins=1&logins=2), matching ASP.NET Core's default query-string binding for array
        #   parameters. Scalars keep the single "key=value" form.
        $qsParts = [System.Collections.Generic.List[string]]::new()
        foreach ($kv in $q.GetEnumerator()) {
            foreach ($v in @($kv.Value)) {
                $qsParts.Add(("{0}={1}" -f $kv.Key, [uri]::EscapeDataString([string]$v)))
            }
        }
        $qs = $qsParts -join '&'
        $uri = "$($ctx.BaseUrl)$Path"
        if ($qs) { $uri = "$uri`?$qs" }

        $irmArgs = @{ Method = $Method; Uri = $uri; Headers = $headers }
        if ($null -ne $Body) { $irmArgs.Body = ($Body | ConvertTo-Json -Depth 20); $irmArgs.ContentType = 'application/json' }

        $resp = Invoke-RestMethod @irmArgs

        $errObj = Get-EnvProp $resp 'error'
        if ($errObj) {
            $metaObj     = Get-EnvProp $resp 'meta'
            $activityId  = Get-EnvProp $metaObj 'activityId'
            $code        = Get-EnvProp $errObj 'code'
            $errMessage  = Get-EnvProp $errObj 'message'
            $managerCode = Get-EnvProp $errObj 'managerCode'
            $msg = if ($errMessage) { $errMessage } else { "v2 error: $code" }
            $rec = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("$msg (code=$code; activityId=$activityId; managerCode=$managerCode)"),
                "MyWebApiError,$code",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null)
            $PSCmdlet.ThrowTerminatingError($rec)
        }

        $dataObj = Get-EnvProp $resp 'data'
        if ($All) {
            if ($null -ne $dataObj) {
                foreach ($item in @($dataObj)) { $accumulated.Add($item) }
            }
            $metaObj = Get-EnvProp $resp 'meta'
            $paging  = Get-EnvProp $metaObj 'paging'
            $cursor  = Get-EnvProp $paging 'nextCursor'
            $more    = [bool]($paging -and (Get-EnvProp $paging 'hasMore') -and $cursor)
        } else {
            return $dataObj
        }
    } while ($All -and $more)

    return $accumulated.ToArray()
}
