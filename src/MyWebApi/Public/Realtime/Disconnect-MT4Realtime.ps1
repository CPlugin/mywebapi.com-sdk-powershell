function Disconnect-MT4Realtime {
    <# .SYNOPSIS Stops and disposes an MT4 real-time connection. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject] $Connection)
    $Connection.Sink.StopAsync().GetAwaiter().GetResult()
    $Connection.Sink.Dispose()
}
