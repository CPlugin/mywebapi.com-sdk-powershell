function Get-MT4SymbolSessionsGet {
    <#
    .SYNOPSIS
        Get symbol sessions
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Symbol,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/SymbolSessionsGet/$([uri]::EscapeDataString([string]$Symbol))"; TradePlatform = $TradePlatform }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
