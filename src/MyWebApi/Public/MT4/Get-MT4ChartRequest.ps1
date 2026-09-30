function Get-MT4ChartRequest {
    <#
    .SYNOPSIS
        Get chart bars
    .PARAMETER RequestTimeout
        How long the server waits for the trading platform, in seconds (1-300).
        Default for this operation: 30 s (history or report).
        Overrides the session default set with Connect-MyWebApi -RequestTimeout.
        When the platform does not answer in time the error code is Timeout: nothing was changed and the request is safe to repeat.
    #>
    [CmdletBinding()]
    param(
        [Parameter()][object] $Connection,
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Symbol,
        [Parameter()][string] $Period,
        [Parameter()][string] $Start,
        [Parameter()][string] $End,
        [Parameter()][string] $Mode,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey,
        [Parameter()][ValidateRange(1, 300)][double] $RequestTimeout
    )
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Period')) { $q['period'] = $Period }
    if ($PSBoundParameters.ContainsKey('Start')) { $q['start'] = $Start }
    if ($PSBoundParameters.ContainsKey('End')) { $q['end'] = $End }
    if ($PSBoundParameters.ContainsKey('Mode')) { $q['mode'] = $Mode }
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/ChartRequest/$([uri]::EscapeDataString([string]$Symbol))"; TradePlatform = $TradePlatform; Query = $q; DefaultRequestTimeout = 30 }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    if ($PSBoundParameters.ContainsKey('RequestTimeout')) { $reqArgs.RequestTimeout = $RequestTimeout }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
