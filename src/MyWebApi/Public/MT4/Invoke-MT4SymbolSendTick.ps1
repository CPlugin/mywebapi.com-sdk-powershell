function Invoke-MT4SymbolSendTick {
    <#
    .SYNOPSIS
        Send synthetic tick
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][object] $Connection,
        [Parameter()][string] $TradePlatform,
        [Parameter()][string] $Symbol,
        [Parameter()][double] $Bid,
        [Parameter()][double] $Ask,
        [Parameter()][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    if (-not $PSCmdlet.ShouldProcess('MT4/SymbolSendTick')) { return }
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Symbol')) { $q['symbol'] = $Symbol }
    if ($PSBoundParameters.ContainsKey('Bid')) { $q['bid'] = $Bid }
    if ($PSBoundParameters.ContainsKey('Ask')) { $q['ask'] = $Ask }
    $reqArgs = @{ Method = 'Post'; Path = "/api/v2/MT4/{tradePlatform}/SymbolSendTick"; TradePlatform = $TradePlatform; Query = $q; Body = $Body }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
