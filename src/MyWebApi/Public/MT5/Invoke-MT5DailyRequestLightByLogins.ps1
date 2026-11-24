function Invoke-MT5DailyRequestLightByLogins {
    <#
    .SYNOPSIS
        Lightweight daily reports of several accounts
    .PARAMETER Body
        Logins of the accounts to read.
        Pass any value that ConvertTo-Json can serialize (a hashtable or [pscustomobject] for an object).
    .PARAMETER RequestTimeout
        How long the server waits for the trading platform, in seconds (1-300).
        Default for this operation: 30 s (history or report).
        Overrides the session default set with Connect-MyWebApi -RequestTimeout.
        When the platform does not answer in time the error code is Timeout: nothing was changed and the request is safe to repeat.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][object] $Connection,
        [Parameter()][string] $TradePlatform,
        [Parameter()][long] $From,
        [Parameter()][long] $To,
        [Parameter()][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey,
        [Parameter()][ValidateRange(1, 300)][double] $RequestTimeout
    )
    if (-not $PSCmdlet.ShouldProcess('MT5/DailyRequestLightByLogins')) { return }
    $q = @{}
    if ($PSBoundParameters.ContainsKey('From')) { $q['from'] = $From }
    if ($PSBoundParameters.ContainsKey('To')) { $q['to'] = $To }
    $reqArgs = @{ Method = 'Post'; Path = "/api/v2/MT5/{tradePlatform}/DailyRequestLightByLogins"; TradePlatform = $TradePlatform; Query = $q; Body = $Body; DefaultRequestTimeout = 30 }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    if ($PSBoundParameters.ContainsKey('RequestTimeout')) { $reqArgs.RequestTimeout = $RequestTimeout }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
