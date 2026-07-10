function Get-MT4TradeRecordsRequest {
    <#
    .SYNOPSIS
        Get trade records batch (live)
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][int[]] $Orders,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Orders')) { $q['orders'] = $Orders }
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/TradeRecordsRequest"; TradePlatform = $TradePlatform; Query = $q }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
