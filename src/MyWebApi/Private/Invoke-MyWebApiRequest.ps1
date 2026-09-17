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
        [switch]    $All,
        [object]    $Connection
    )

    $ctx = Resolve-MyWebApiContext -Connection $Connection
    $safeMethod = $Method.ToUpperInvariant() -in @('GET', 'HEAD', 'OPTIONS')
    $configuredRetries = Get-MyWebApiContextProperty -Context $ctx -Name 'MaxGetRetries'
    $maxRetries = if ($safeMethod -and $null -ne $configuredRetries) { [Math]::Min([int]$configuredRetries, 3) } else { 0 }

    # Resolve {tradePlatform} from the explicit connection or the session default.
    if ($Path -like '*{tradePlatform}*') {
        $defaultPlatform = Get-MyWebApiContextProperty -Context $ctx -Name 'DefaultTradePlatform'
        $tp = if ($TradePlatform) { $TradePlatform } else { $defaultPlatform }
        if (-not $tp) { throw 'No trade platform: pass -TradePlatform or set -DefaultTradePlatform on Connect-MyWebApi.' }
        $Path = $Path.Replace('{tradePlatform}', [uri]::EscapeDataString($tp))
    }

    $token = Get-MyWebApiToken -Connection $ctx
    $headers = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
    if ($IdempotencyKey) { $headers['Idempotency-Key'] = $IdempotencyKey }

    $q = @{}
    if ($Query) { foreach ($k in $Query.Keys) { if ($null -ne $Query[$k]) { $q[$k] = $Query[$k] } } }
    if ($CacheId)      { $q['cacheId']      = $CacheId.ToString() }
    if ($CacheTimeout) { $q['cacheTimeout'] = $CacheTimeout }

    $accumulated = [System.Collections.Generic.List[object]]::new()
    $cursor = $null
    $more = $false

    do {
        if ($All -and $cursor) { $q['cursor'] = $cursor }
        $qsParts = [System.Collections.Generic.List[string]]::new()
        foreach ($kv in $q.GetEnumerator()) {
            foreach ($v in @($kv.Value)) {
                $qsParts.Add(("{0}={1}" -f [uri]::EscapeDataString([string]$kv.Key), [uri]::EscapeDataString([string]$v)))
            }
        }
        $qs = $qsParts -join '&'
        $baseUrl = [string](Get-MyWebApiContextProperty -Context $ctx -Name 'BaseUrl')
        $uri = "$baseUrl$Path"
        if ($qs) { $uri = "$uri`?$qs" }

        $irmArgs = @{
            Context = $ctx
            Method = $Method
            Uri = $uri
            Headers = $headers
            JsonBody = $Body
        }

        # GET/HEAD/OPTIONS are safe to retry with a bounded policy. Writes are always
        # one-shot, regardless of Idempotency-Key: a lost response is an ambiguous outcome.
        $attempt = 0
        while ($true) {
            try {
                Assert-MyWebApiNotCancelled -Context $ctx
                $resp = Invoke-MyWebApiHttpJson @irmArgs
                break
            } catch {
                $statusCode = $null
                $responseProperty = $_.Exception.PSObject.Properties['Response']
                if ($responseProperty -and $responseProperty.Value) {
                    try { $statusCode = [int]$responseProperty.Value.StatusCode } catch { $statusCode = $null }
                }
                if ($null -eq $statusCode) {
                    $dataStatus = $_.Exception.Data['StatusCode']
                    if ($null -ne $dataStatus) { $statusCode = [int]$dataStatus }
                }
                $retryableStatus = $statusCode -in @(408, 425, 429, 500, 502, 503, 504)
                $retryable = $safeMethod -and $attempt -lt $maxRetries -and ($retryableStatus -or $null -eq $statusCode)
                if (-not $retryable) { throw }
                $delayMs = [Math]::Min(250 * [Math]::Pow(2, $attempt), 2000)
                if ((Get-MyWebApiCancellationToken -Context $ctx).WaitHandle.WaitOne([int]$delayMs)) {
                    throw [System.OperationCanceledException]::new('The WebAPI session operation was cancelled.')
                }
                $attempt++
            }
        }

        $errObj = Get-MyWebApiContextProperty -Context $resp -Name 'error'
        if ($errObj) {
            $metaObj     = Get-MyWebApiContextProperty -Context $resp -Name 'meta'
            $activityId  = Get-MyWebApiContextProperty -Context $metaObj -Name 'activityId'
            $code        = Get-MyWebApiContextProperty -Context $errObj -Name 'code'
            $errMessage  = Get-MyWebApiContextProperty -Context $errObj -Name 'message'
            $managerCode = Get-MyWebApiContextProperty -Context $errObj -Name 'managerCode'
            $msg = if ($errMessage) { $errMessage } else { "v2 error: $code" }
            $rec = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("$msg (code=$code; activityId=$activityId; managerCode=$managerCode)"),
                "MyWebApiError,$code",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null)
            $PSCmdlet.ThrowTerminatingError($rec)
        }

        $dataObj = Get-MyWebApiContextProperty -Context $resp -Name 'data'
        if ($All) {
            if ($null -ne $dataObj) {
                foreach ($item in @($dataObj)) { $accumulated.Add($item) }
            }
            $metaObj = Get-MyWebApiContextProperty -Context $resp -Name 'meta'
            $paging  = Get-MyWebApiContextProperty -Context $metaObj -Name 'paging'
            $cursor  = Get-MyWebApiContextProperty -Context $paging -Name 'nextCursor'
            $more    = [bool]($paging -and (Get-MyWebApiContextProperty -Context $paging -Name 'hasMore') -and $cursor)
        } else {
            return $dataObj
        }
    } while ($All -and $more)

    return $accumulated.ToArray()
}
