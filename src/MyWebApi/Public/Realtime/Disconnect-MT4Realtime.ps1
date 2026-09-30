function Disconnect-MT4Realtime {
    <# .SYNOPSIS Stops and disposes an MT4 real-time connection. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject] $Connection)
    $timeout = if ($Connection.Session -and $Connection.Session.RealtimeTimeoutSeconds) { [int]$Connection.Session.RealtimeTimeoutSeconds } else { 30 }
    $failure = $null
    try {
        [void]$Connection.Sink.StopAsync([Math]::Min($timeout, 3600) * 1000).GetAwaiter().GetResult()
    } catch {
        $failure = $_.Exception
    } finally {
        try { $Connection.Sink.Dispose() } catch {
            if ($null -eq $failure) { $failure = $_.Exception }
        }
    }
    if ($failure) { throw "Failed to stop MT4 realtime connection: $($failure.Message)" }
}
