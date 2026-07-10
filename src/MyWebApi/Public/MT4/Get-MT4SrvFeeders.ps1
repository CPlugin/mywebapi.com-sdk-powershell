function Get-MT4SrvFeeders {
    <#
    .SYNOPSIS
        List data feeders
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][int] $Limit,
        [Parameter()][string] $Cursor,
        [Parameter()][switch] $All,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Limit')) { $q['limit'] = $Limit }
    if ($PSBoundParameters.ContainsKey('Cursor')) { $q['cursor'] = $Cursor }
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/SrvFeeders"; TradePlatform = $TradePlatform; Query = $q }
    if ($All) { $reqArgs.All = $true }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
