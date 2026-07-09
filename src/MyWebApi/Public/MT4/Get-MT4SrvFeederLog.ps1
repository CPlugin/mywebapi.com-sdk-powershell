function Get-MT4SrvFeederLog {
    <#
    .SYNOPSIS
        Get feeder log
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Name,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/SrvFeederLog/$([uri]::EscapeDataString([string]$Name))"; TradePlatform = $TradePlatform }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
