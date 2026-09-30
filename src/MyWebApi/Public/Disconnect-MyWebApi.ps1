function Disconnect-MyWebApi {
    <#
    .SYNOPSIS
        Clears and disposes one WebAPI session.
    .PARAMETER Connection
        A session returned by Connect-MyWebApi. Omitting it disconnects the optional default.
    #>
    [CmdletBinding()]
    param([object] $Connection)

    $ctx = Resolve-MyWebApiContext -Connection $Connection
    if ([bool](Get-MyWebApiContextProperty -Context $ctx -Name 'Disposed')) { return }
    $source = Get-MyWebApiContextProperty -Context $ctx -Name 'CancellationSource'
    if ($source) { try { $source.Cancel() } catch { Write-Verbose "Cancellation failed: $($_.Exception.Message)" } }
    Set-MyWebApiContextProperty -Context $ctx -Name 'Disposed' -Value $true
    $secret = Get-MyWebApiContextProperty -Context $ctx -Name 'ClientSecret'
    if ($secret -is [System.Security.SecureString]) {
        try { $secret.Dispose() } catch { Write-Verbose "SecureString disposal failed: $($_.Exception.Message)" }
    }
    $gate = Get-MyWebApiContextProperty -Context $ctx -Name 'RefreshGate'
    if ($gate) {
        try { $gate.Dispose() } catch { Write-Verbose "Token refresh gate disposal failed: $($_.Exception.Message)" }
    }
    if ([object]::ReferenceEquals($script:MyWebApiContext, $ctx)) {
        $script:MyWebApiContext = $null
    }
}
