function Get-MT4TradesRequest {
    <#
    .SYNOPSIS
        Query trades (live)
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][int] $Limit,
        [Parameter()][string] $Cursor,
        [Parameter()][string] $Group,
        [Parameter()][switch] $All,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Limit')) { $q['limit'] = $Limit }
    if ($PSBoundParameters.ContainsKey('Cursor')) { $q['cursor'] = $Cursor }
    if ($PSBoundParameters.ContainsKey('Group')) { $q['group'] = $Group }
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/TradesRequest"; TradePlatform = $TradePlatform; Query = $q }
    if ($All) { $reqArgs.All = $true }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
