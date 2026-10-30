function Receive-MT5Realtime {
    <#
    .SYNOPSIS
        Streams real-time payloads from an MT5 connection to the pipeline.
    .DESCRIPTION
        Returns payloads as objects with Method and Payload properties until the connection
        stops or no payload arrives within TimeoutSeconds. Tick subscriptions made with
        Register-MT5Realtime -Category Ticks arrive as Method OnTick with a payload of symbol,
        bid, ask, last, lastTime, volumeExt and flags; batched subscriptions (-Category
        TicksBatch) arrive as Method OnTicksBatch with a payload of symbol and ticks, each tick
        carrying the same fields. Margin-call updates keep their own method name.
    .PARAMETER Connection
        Connection object returned by Connect-MT5Realtime.
    .PARAMETER TimeoutSeconds
        How long to wait for the next payload before the cmdlet returns, in seconds (1-3600).
    .EXAMPLE
        Receive-MT5Realtime -Connection $rt -TimeoutSeconds 10 |
            Where-Object Method -eq 'OnTick' |
            ForEach-Object { '{0}  bid={1} ask={2}' -f $_.Payload.symbol, $_.Payload.bid, $_.Payload.ask }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [ValidateRange(1, 3600)][int] $TimeoutSeconds = 30
    )
    $timeoutMs = $TimeoutSeconds * 1000
    while ($true) {
        if ($Connection.Sink.HasFault) {
            throw "Realtime connection fault: $($Connection.Sink.Fault.Message)"
        }
        $item = $null
        try {
            $received = $Connection.Sink.TryTake([ref]$item, $timeoutMs)
        } catch {
            if ($Connection.Sink.HasFault) { throw "Realtime connection fault: $($Connection.Sink.Fault.Message)" }
            throw
        }
        if (-not $received) {
            if ($Connection.Sink.HasFault) { throw "Realtime connection fault: $($Connection.Sink.Fault.Message)" }
            break
        }
        if ($item.Error) { throw "Realtime connection fault: $($item.Error.Message)" }
        [pscustomobject]@{
            Method  = $item.Method
            Payload = ($item.Json | ConvertFrom-Json -Depth 20)
        }
    }
}
