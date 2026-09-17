function Get-MT4TradesUserHistory {
    <#
    .SYNOPSIS
        Get account trade history
    #>
    [CmdletBinding()]
    param(
        [Parameter()][object] $Connection,
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Login,
        [Parameter()][string] $FromTime,
        [Parameter()][string] $ToTime,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $q = @{}
    if ($PSBoundParameters.ContainsKey('FromTime')) { $q['fromTime'] = $FromTime }
    if ($PSBoundParameters.ContainsKey('ToTime')) { $q['toTime'] = $ToTime }
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/TradesUserHistory/$([uri]::EscapeDataString([string]$Login))"; TradePlatform = $TradePlatform; Query = $q }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
