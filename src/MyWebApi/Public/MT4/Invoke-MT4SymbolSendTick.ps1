function Invoke-MT4SymbolSendTick {
    <#
    .SYNOPSIS
        Send synthetic tick
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    if (-not $PSCmdlet.ShouldProcess('MT4/SymbolSendTick')) { return }
    $reqArgs = @{ Method = 'Post'; Path = "/api/v2/MT4/{tradePlatform}/SymbolSendTick"; TradePlatform = $TradePlatform; Body = $Body }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
