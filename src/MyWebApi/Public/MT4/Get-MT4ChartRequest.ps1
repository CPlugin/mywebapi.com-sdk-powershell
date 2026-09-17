function Get-MT4ChartRequest {
    <#
    .SYNOPSIS
        Get chart bars
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
        [Parameter()][string] $IdempotencyKey
    )
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Period')) { $q['period'] = $Period }
    if ($PSBoundParameters.ContainsKey('Start')) { $q['start'] = $Start }
    if ($PSBoundParameters.ContainsKey('End')) { $q['end'] = $End }
    if ($PSBoundParameters.ContainsKey('Mode')) { $q['mode'] = $Mode }
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/ChartRequest/$([uri]::EscapeDataString([string]$Symbol))"; TradePlatform = $TradePlatform; Query = $q }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
