function Disconnect-MT5Realtime {
    <# .SYNOPSIS Stops and disposes an MT5 real-time connection. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject] $Connection)
    $Connection.Sink.StopAsync().GetAwaiter().GetResult()
    $Connection.Sink.Dispose()
}
