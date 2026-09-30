# * The server may take longer than the requested timeout to answer: time spent opening the
#   trade-platform connection extends its deadline by up to 20 s. The HTTP call's own deadline
#   therefore sits this far beyond the server's, so the server's answer (Timeout, OutcomeUnknown)
#   arrives instead of an ambiguous client-side abort.
$script:MyWebApiServerDeadlineMarginSeconds = 30
# * Operations the spec does not annotate with a default timeout are assumed to take the
#   longest server default (server maintenance, 60 s) when sizing the HTTP deadline.
$script:MyWebApiUnknownServerTimeoutSeconds = 60

function Get-MyWebApiErrorGuidance {
    # Plain-language next step for the error codes and outcomes whose handling is not obvious.
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string] $Code,
        [string] $Outcome,
        [string] $IdempotencyKey
    )
    switch ($Code) {
        'Timeout' {
            return 'The trading platform did not answer in time. Nothing was changed; the request is safe to repeat. Allow more time with -RequestTimeout.'
        }
        'Busy' {
            return 'The trading platform is busy: the request was refused before it was sent and nothing was changed. Repeat it after a short pause.'
        }
        'OutcomeUnknown' {
            if ($Outcome -eq 'in-progress') {
                return 'A request with the same Idempotency-Key is still being processed and was not executed again. Repeat later with the same -IdempotencyKey to receive its result.'
            }
            if ($IdempotencyKey) {
                return 'The operation did not finish in time and may still be applied by the trading platform. Do not repeat it blindly: repeat with the same -IdempotencyKey to receive the original result, or check the result first.'
            }
            return 'The operation did not finish in time and may still be applied by the trading platform. Do not repeat it blindly: check the result first. Pass -IdempotencyKey on writes so that a repeat returns the original result instead of executing twice.'
        }
    }
    return $null
}

function ConvertTo-MyWebApiErrorRecord {
    # Builds the terminating error for a v2 error envelope or a client-side HTTP deadline. The
    # same details are on TargetObject (for $_.TargetObject.Code) and on Exception.Data (for
    # callers that only keep the exception).
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)][string] $ErrorId,
        [Parameter(Mandatory)][string] $Message,
        [Parameter(Mandatory)][hashtable] $Details,
        [System.Exception] $InnerException
    )
    $guidance = $Details['Guidance']
    $fullMessage = if ($guidance) { "$Message $guidance" } else { $Message }
    $exception = if ($InnerException) { [System.Exception]::new($fullMessage, $InnerException) } else { [System.Exception]::new($fullMessage) }
    foreach ($key in $Details.Keys) { $exception.Data[$key] = $Details[$key] }

    $category = switch ($Details['Code']) {
        'Timeout'        { [System.Management.Automation.ErrorCategory]::OperationTimeout }
        'OutcomeUnknown' { [System.Management.Automation.ErrorCategory]::OperationTimeout }
        'Busy'           { [System.Management.Automation.ErrorCategory]::ResourceBusy }
        default {
            if ($Details['Source'] -eq 'client') { [System.Management.Automation.ErrorCategory]::OperationTimeout }
            else { [System.Management.Automation.ErrorCategory]::InvalidOperation }
        }
    }
    $record = [System.Management.Automation.ErrorRecord]::new($exception, $ErrorId, $category, [pscustomobject]$Details)
    if ($guidance) {
        $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($fullMessage)
        $record.ErrorDetails.RecommendedAction = $guidance
    }
    return $record
}

function Invoke-MyWebApiRequest {
    # Single choke point for every REST cmdlet: auth, URL build, timeouts, envelope unwrap, paging.
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
        [ValidateRange(1, 300)][double] $RequestTimeout,
        [ValidateRange(1, 300)][double] $DefaultRequestTimeout,
        [switch]    $All,
        [object]    $Connection
    )

    $ctx = Resolve-MyWebApiContext -Connection $Connection
    $safeMethod = $Method.ToUpperInvariant() -in @('GET', 'HEAD', 'OPTIONS')
    $configuredRetries = Get-MyWebApiContextProperty -Context $ctx -Name 'MaxGetRetries'
    $maxRetries = if ($safeMethod -and $null -ne $configuredRetries) { [Math]::Min([int]$configuredRetries, 3) } else { 0 }
    $platformCall = $Path -like '*{tradePlatform}*'

    # Resolve {tradePlatform} from the explicit connection or the session default.
    if ($platformCall) {
        $defaultPlatform = Get-MyWebApiContextProperty -Context $ctx -Name 'DefaultTradePlatform'
        $tp = if ($TradePlatform) { $TradePlatform } else { $defaultPlatform }
        if (-not $tp) { throw 'No trade platform: pass -TradePlatform or set -DefaultTradePlatform on Connect-MyWebApi.' }
        $Path = $Path.Replace('{tradePlatform}', [uri]::EscapeDataString($tp))
    }

    # * Request timeout: the cmdlet's -RequestTimeout wins over the session default; with neither,
    #   no header is sent and the server applies the operation's own default.
    $requestedTimeout = $null
    if ($PSBoundParameters.ContainsKey('RequestTimeout')) {
        $requestedTimeout = $RequestTimeout
    } else {
        $sessionTimeout = Get-MyWebApiContextProperty -Context $ctx -Name 'RequestTimeout'
        if ($null -ne $sessionTimeout) {
            $parsed = 0.0
            if (-not [double]::TryParse([string]$sessionTimeout, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed) -or $parsed -lt 1 -or $parsed -gt 300) {
                throw "The session RequestTimeout must be a number of seconds from 1 to 300; got '$sessionTimeout'."
            }
            $requestedTimeout = $parsed
        }
    }
    $serverTimeout = if ($null -ne $requestedTimeout) { $requestedTimeout }
                     elseif ($PSBoundParameters.ContainsKey('DefaultRequestTimeout')) { $DefaultRequestTimeout }
                     elseif ($platformCall) { $script:MyWebApiUnknownServerTimeoutSeconds }
                     else { $null }
    # * HTTP deadline: an explicitly requested server timeout always gets its margin. Otherwise an
    #   HttpTimeoutSeconds the caller chose on Connect-MyWebApi is a hard cap and is kept as is;
    #   the module default is only a floor under the operation's server default plus the margin.
    $httpTimeout = Get-MyWebApiTimeoutSeconds -Context $ctx
    $httpTimeoutExplicit = [bool](Get-MyWebApiContextProperty -Context $ctx -Name 'HttpTimeoutExplicit')
    if ($null -ne $serverTimeout -and ($null -ne $requestedTimeout -or -not $httpTimeoutExplicit)) {
        $needed = [int][Math]::Ceiling($serverTimeout + $script:MyWebApiServerDeadlineMarginSeconds)
        $httpTimeout = [Math]::Min(600, [Math]::Max($httpTimeout, $needed))
    }

    $token = Get-MyWebApiToken -Connection $ctx
    $headers = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
    if ($IdempotencyKey) { $headers['Idempotency-Key'] = $IdempotencyKey }
    if ($null -ne $requestedTimeout) {
        $headers['X-Request-Timeout'] = ([double]$requestedTimeout).ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
    }

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

        # GET/HEAD/OPTIONS are safe to retry with a bounded policy: transport failures, retryable
        # HTTP statuses and a Busy refusal (nothing was sent to the platform). A Timeout is not
        # retried automatically -- the platform is slow, and the caller decides whether to wait
        # longer. Writes are always one-shot, regardless of Idempotency-Key: a lost response or an
        # OutcomeUnknown is an ambiguous outcome that only the caller can resolve.
        $attempt = 0
        while ($true) {
            $responseHeaders = @{}
            $irmArgs = @{
                Context = $ctx
                Method = $Method
                Uri = $uri
                Headers = $headers
                JsonBody = $Body
                TimeoutSeconds = $httpTimeout
                ResponseHeaders = $responseHeaders
            }
            $retryDelay = $false
            try {
                Assert-MyWebApiNotCancelled -Context $ctx
                $resp = Invoke-MyWebApiHttpJson @irmArgs
                $errProbe = Get-MyWebApiContextProperty -Context $resp -Name 'error'
                $busy = $errProbe -and ((Get-MyWebApiContextProperty -Context $errProbe -Name 'code') -eq 'Busy')
                if ($busy -and $safeMethod -and $attempt -lt $maxRetries) { $retryDelay = $true } else { break }
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
                if (-not $retryable) {
                    if ($_.Exception -is [System.TimeoutException]) {
                        # * The HTTP deadline passed without any answer. For a write this is the
                        #   same ambiguity as OutcomeUnknown and is reported the same way.
                        $details = @{
                            Code = $null; Source = 'client'; Outcome = if ($safeMethod) { 'timeout' } else { 'unknown' }
                            Retryable = $safeMethod; Method = $Method.ToUpperInvariant(); Path = $Path
                            IdempotencyKey = $IdempotencyKey; RequestTimeout = $requestedTimeout; HttpTimeoutSeconds = $httpTimeout
                            ActivityId = $null; ManagerCode = $null; RequestTimeoutApplied = $null
                            Guidance = Get-MyWebApiErrorGuidance -Code $(if ($safeMethod) { 'Timeout' } else { 'OutcomeUnknown' }) -IdempotencyKey $IdempotencyKey
                        }
                        $PSCmdlet.ThrowTerminatingError((ConvertTo-MyWebApiErrorRecord -ErrorId 'MyWebApiHttpTimeout' `
                            -Message ("No HTTP response within {0} s." -f $httpTimeout) -Details $details -InnerException $_.Exception))
                    }
                    throw
                }
                $retryDelay = $true
            }
            if ($retryDelay) {
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
            $code        = [string](Get-MyWebApiContextProperty -Context $errObj -Name 'code')
            $errMessage  = Get-MyWebApiContextProperty -Context $errObj -Name 'message'
            $managerCode = Get-MyWebApiContextProperty -Context $errObj -Name 'managerCode'
            $outcome     = $responseHeaders['X-Request-Outcome']
            $applied     = $responseHeaders['X-Request-Timeout-Applied']
            $msg = if ($errMessage) { $errMessage } else { "v2 error: $code" }
            $suffix = "code=$code; activityId=$activityId; managerCode=$managerCode"
            if ($outcome) { $suffix += "; outcome=$outcome" }
            if ($applied) { $suffix += "; requestTimeoutApplied=$applied" }
            $details = @{
                Code = $code; Source = 'server'; Outcome = $outcome; RequestTimeoutApplied = $applied
                Retryable = $code -in @('Timeout', 'Busy'); Method = $Method.ToUpperInvariant(); Path = $Path
                IdempotencyKey = $IdempotencyKey; RequestTimeout = $requestedTimeout; HttpTimeoutSeconds = $httpTimeout
                ActivityId = $activityId; ManagerCode = $managerCode
                Guidance = Get-MyWebApiErrorGuidance -Code $code -Outcome $outcome -IdempotencyKey $IdempotencyKey
            }
            $PSCmdlet.ThrowTerminatingError((ConvertTo-MyWebApiErrorRecord -ErrorId "MyWebApiError,$code" -Message "$msg ($suffix)." -Details $details))
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
