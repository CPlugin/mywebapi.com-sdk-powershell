function Receive-MT4Realtime {
    <# .SYNOPSIS Streams real-time payloads from an MT4 connection to the pipeline. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [int] $TimeoutSeconds = 0   # 0 = block indefinitely per item
    )
    $timeoutMs = if ($TimeoutSeconds -gt 0) { $TimeoutSeconds * 1000 } else { -1 }
    while ($true) {
        $item = $null
        if ($Connection.Sink.TryTake([ref]$item, $timeoutMs)) {
            [pscustomobject]@{
                Method  = $item.Method
                Payload = ($item.Json | ConvertFrom-Json -Depth 20)
            }
        } elseif ($TimeoutSeconds -gt 0) {
            break   # timed out with nothing to yield
        }
    }
}
