function Get-MT5GroupGet {
    <#
    .SYNOPSIS
        Get a group by name
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Group,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT5/{tradePlatform}/GroupGet/$([uri]::EscapeDataString([string]$Group))"; TradePlatform = $TradePlatform }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
