function Get-MT4AdmTradesRequest {
    <#
    .SYNOPSIS
        List group trades (admin)
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Group,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/AdmTradesRequest/$([uri]::EscapeDataString([string]$Group))"; TradePlatform = $TradePlatform }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
