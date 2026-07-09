function Invoke-MT4CfgUpdateDataServer {
    <#
    .SYNOPSIS
        Update data-server entry
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Pos,
        [Parameter()][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    if (-not $PSCmdlet.ShouldProcess('MT4/CfgUpdateDataServer')) { return }
    $reqArgs = @{ Method = 'Post'; Path = "/api/v2/MT4/{tradePlatform}/CfgUpdateDataServer/$([uri]::EscapeDataString([string]$Pos))"; TradePlatform = $TradePlatform; Body = $Body }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
