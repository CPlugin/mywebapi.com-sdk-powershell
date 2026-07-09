function Invoke-MT4UserRecordNew {
    <#
    .SYNOPSIS
        Create account
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    if (-not $PSCmdlet.ShouldProcess('MT4/UserRecordNew')) { return }
    $reqArgs = @{ Method = 'Post'; Path = "/api/v2/MT4/{tradePlatform}/UserRecordNew"; TradePlatform = $TradePlatform; Body = $Body }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
