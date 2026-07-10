function Get-MT4UserRecordsRequest {
    <#
    .SYNOPSIS
        Get accounts batch (live)
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][int[]] $Logins,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Logins')) { $q['logins'] = $Logins }
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/UserRecordsRequest"; TradePlatform = $TradePlatform; Query = $q }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
