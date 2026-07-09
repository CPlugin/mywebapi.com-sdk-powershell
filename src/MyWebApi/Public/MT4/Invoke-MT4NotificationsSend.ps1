function Invoke-MT4NotificationsSend {
    <#
    .SYNOPSIS
        Invoke-MT4NotificationsSend
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    if (-not $PSCmdlet.ShouldProcess('MT4/NotificationsSend')) { return }
    $reqArgs = @{ Method = 'Post'; Path = "/api/v2/MT4/{tradePlatform}/NotificationsSend"; TradePlatform = $TradePlatform; Body = $Body }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
