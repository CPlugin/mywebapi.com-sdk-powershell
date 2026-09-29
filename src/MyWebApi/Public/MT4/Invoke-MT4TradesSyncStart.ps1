function Invoke-MT4TradesSyncStart {
    <#
    .SYNOPSIS
        Start trade-records sync
    .PARAMETER RequestTimeout
        How long the server waits for the trading platform, in seconds (1-300).
        Default for this operation: 60 s (server maintenance).
        Overrides the session default set with Connect-MyWebApi -RequestTimeout.
        When the platform does not answer in time the error code is OutcomeUnknown: the change may still be applied, so check the result or repeat with the same -IdempotencyKey instead of repeating blindly.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][object] $Connection,
        [Parameter()][string] $TradePlatform,
        [Parameter()][int] $Timestamp,
        [Parameter()][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey,
        [Parameter()][ValidateRange(1, 300)][double] $RequestTimeout
    )
    if (-not $PSCmdlet.ShouldProcess('MT4/TradesSyncStart')) { return }
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Timestamp')) { $q['timestamp'] = $Timestamp }
    $reqArgs = @{ Method = 'Post'; Path = "/api/v2/MT4/{tradePlatform}/TradesSyncStart"; TradePlatform = $TradePlatform; Query = $q; Body = $Body; DefaultRequestTimeout = 60 }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    if ($PSBoundParameters.ContainsKey('RequestTimeout')) { $reqArgs.RequestTimeout = $RequestTimeout }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
