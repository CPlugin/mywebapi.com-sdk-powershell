function Invoke-MT5ChartSplit {
    <#
    .SYNOPSIS
        Split the price history of a symbol
    .PARAMETER Body
        Request body, sent as JSON.
        Pass any value that ConvertTo-Json can serialize (a hashtable or [pscustomobject] for an object).
    .PARAMETER RequestTimeout
        How long the server waits for the trading platform, in seconds (1-300).
        Default for this operation: 5 s (trade operation).
        Overrides the session default set with Connect-MyWebApi -RequestTimeout.
        When the platform does not answer in time the error code is OutcomeUnknown: the change may still be applied, so check the result or repeat with the same -IdempotencyKey instead of repeating blindly.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][object] $Connection,
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Symbol,
        [Parameter()][int] $NewShares,
        [Parameter()][int] $OldShares,
        [Parameter()][string] $RoundingRule,
        [Parameter()][string] $From,
        [Parameter()][string] $To,
        [Parameter()][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey,
        [Parameter()][ValidateRange(1, 300)][double] $RequestTimeout
    )
    if (-not $PSCmdlet.ShouldProcess('MT5/ChartSplit')) { return }
    $q = @{}
    if ($PSBoundParameters.ContainsKey('NewShares')) { $q['newShares'] = $NewShares }
    if ($PSBoundParameters.ContainsKey('OldShares')) { $q['oldShares'] = $OldShares }
    if ($PSBoundParameters.ContainsKey('RoundingRule')) { $q['roundingRule'] = $RoundingRule }
    if ($PSBoundParameters.ContainsKey('From')) { $q['from'] = $From }
    if ($PSBoundParameters.ContainsKey('To')) { $q['to'] = $To }
    $reqArgs = @{ Method = 'Post'; Path = "/api/v2/MT5/{tradePlatform}/ChartSplit/$([uri]::EscapeDataString([string]$Symbol))"; TradePlatform = $TradePlatform; Query = $q; Body = $Body; DefaultRequestTimeout = 5 }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    if ($PSBoundParameters.ContainsKey('RequestTimeout')) { $reqArgs.RequestTimeout = $RequestTimeout }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
