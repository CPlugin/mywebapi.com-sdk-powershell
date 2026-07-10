function Disconnect-MT4Realtime {
    <# .SYNOPSIS Stops and disposes an MT4 real-time connection. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject] $Connection)
    # * [void]: suppress the void-Task VoidTaskResult sentinel from the pipeline.
    [void]$Connection.Sink.StopAsync().GetAwaiter().GetResult()
    $Connection.Sink.Dispose()
}
