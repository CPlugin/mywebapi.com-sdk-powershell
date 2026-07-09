function Get-MT4BackupRequestUsers {
    <#
    .SYNOPSIS
        Read users from backup
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $File,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    $reqArgs = @{ Method = 'Get'; Path = "/api/v2/MT4/{tradePlatform}/BackupRequestUsers/$([uri]::EscapeDataString([string]$File))"; TradePlatform = $TradePlatform }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
