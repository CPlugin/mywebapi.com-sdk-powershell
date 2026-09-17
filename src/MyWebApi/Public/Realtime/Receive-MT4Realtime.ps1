function Receive-MT4Realtime {
    <# .SYNOPSIS Streams real-time payloads from an MT4 connection to the pipeline. #>
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
