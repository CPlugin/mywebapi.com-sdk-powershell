function Get-MT5DealByGroup {
    <#
    .SYNOPSIS
        List deals by group
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
        [Parameter(Mandatory)][string] $Mask,
        [Parameter()][int] $Limit,
        [Parameter()][string] $Cursor,
        [Parameter()][switch] $All,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey,
        [Parameter()][ValidateRange(1, 300)][double] $RequestTimeout
    )
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Limit')) { $q['limit'] = $Limit }
    if ($PSBoundParameters.ContainsKey('Cursor')) { $q['cursor'] = $Cursor }
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT5/{tradePlatform}/DealByGroup/$([uri]::EscapeDataString([string]$Mask))"; TradePlatform = $TradePlatform; Query = $q; DefaultRequestTimeout = 30 }
    if ($All) { $reqArgs.All = $true }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    if ($PSBoundParameters.ContainsKey('RequestTimeout')) { $reqArgs.RequestTimeout = $RequestTimeout }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
