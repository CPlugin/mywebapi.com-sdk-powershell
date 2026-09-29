function Update-MT5UserRecord {
    <#
    .SYNOPSIS
        Partially update a user
    .PARAMETER Body
        JSON Merge Patch: an object with only the fields to change.
        Pass a hashtable or [pscustomobject]; it is sent as a JSON object.
    .PARAMETER RequestTimeout
        How long the server waits for the trading platform, in seconds (1-300).
        Default for this operation: 15 s (change).
        Overrides the session default set with Connect-MyWebApi -RequestTimeout.
        When the platform does not answer in time the error code is OutcomeUnknown: the change may still be applied, so check the result or repeat with the same -IdempotencyKey instead of repeating blindly.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()][object] $Connection,
        [Parameter()][string] $TradePlatform,
        [Parameter(Mandatory)][string] $Login,
        [Parameter(Mandatory)][ValidateScript({ $_ -is [System.Collections.IDictionary] -or $_.PSObject.BaseObject -is [System.Management.Automation.PSCustomObject] }, ErrorMessage = 'Body must be a hashtable or [pscustomobject] (a JSON object).')][object] $Body,
        [Parameter()][Nullable[guid]] $CacheId,
        [Parameter()][int] $CacheTimeout,
        [Parameter()][string] $IdempotencyKey,
        [Parameter()][ValidateRange(1, 300)][double] $RequestTimeout
    )
    if (-not $PSCmdlet.ShouldProcess('MT5/UserRecord')) { return }
    $reqArgs = @{ Method = 'Patch'; Path = "/api/v2/MT5/{tradePlatform}/UserRecord/$([uri]::EscapeDataString([string]$Login))"; TradePlatform = $TradePlatform; Body = $Body; DefaultRequestTimeout = 15 }
    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }
    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }
    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }
    if ($PSBoundParameters.ContainsKey('RequestTimeout')) { $reqArgs.RequestTimeout = $RequestTimeout }
    Invoke-MyWebApiRequest -Connection $Connection @reqArgs
}
