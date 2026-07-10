function Invoke-MT4CfgShiftGatewayRule {
    <#
    .SYNOPSIS
        Reorder gateway rule
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Pos,
        [Parameter()][int] $Shift,
        [Parameter()][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey
    )
    if (-not $PSCmdlet.ShouldProcess('MT4/CfgShiftGatewayRule')) { return }
    $q = @{}
    if ($PSBoundParameters.ContainsKey('Shift')) { $q['shift'] = $Shift }
    $reqArgs = @{ Method = 'Post'; Path = "/api/v2/MT4/{tradePlatform}/CfgShiftGatewayRule/$([uri]::EscapeDataString([string]$Pos))"; TradePlatform = $TradePlatform; Query = $q; Body = $Body }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    Invoke-MyWebApiRequest @reqArgs
}
