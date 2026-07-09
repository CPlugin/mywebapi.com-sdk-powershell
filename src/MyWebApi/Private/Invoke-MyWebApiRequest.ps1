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
        $qs = ($q.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, [uri]::EscapeDataString([string]$_.Value) }) -join '&'
        $uri = "$($ctx.BaseUrl)$Path"
        if ($qs) { $uri = "$uri`?$qs" }

        $irmArgs = @{ Method = $Method; Uri = $uri; Headers = $headers }
        if ($null -ne $Body) { $irmArgs.Body = ($Body | ConvertTo-Json -Depth 20); $irmArgs.ContentType = 'application/json' }

        $resp = Invoke-RestMethod @irmArgs

        if ($resp.error) {
            $err = $resp.error
            $activityId = if ($resp.meta) { $resp.meta.activityId } else { $null }
            $msg = if ($err.message) { $err.message } else { "v2 error: $($err.code)" }
            $rec = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("$msg (code=$($err.code); activityId=$activityId; managerCode=$($err.managerCode))"),
                "MyWebApiError,$($err.code)",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null)
            $PSCmdlet.ThrowTerminatingError($rec)
        }

        if ($All) {
            if ($null -ne $resp.data) {
                foreach ($item in @($resp.data)) { $accumulated.Add($item) }
            }
            $paging = if ($resp.meta) { $resp.meta.paging } else { $null }
            $cursor = if ($paging) { $paging.nextCursor } else { $null }
            $more = [bool]($paging -and $paging.hasMore -and $paging.nextCursor)
        } else {
            return $resp.data
        }
    } while ($All -and $more)

    return $accumulated.ToArray()
}
