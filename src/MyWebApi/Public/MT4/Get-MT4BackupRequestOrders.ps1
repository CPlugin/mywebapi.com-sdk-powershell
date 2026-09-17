function Get-MT4BackupRequestOrders {
    <#
    .SYNOPSIS
        Read orders from backup
    #>
    [CmdletBinding()]
    param(
        [Parameter()][object] $Connection,
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $File,
        [Parameter()][string] $Request,
        [Parameter()][int] $Limit,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Request')) { $q['request'] = $Request }
    if ($PSBoundParameters.ContainsKey('Limit')) { $q['limit'] = $Limit }
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/BackupRequestOrders/$([uri]::EscapeDataString([string]$File))"; TradePlatform = $TradePlatform; Query = $q }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
