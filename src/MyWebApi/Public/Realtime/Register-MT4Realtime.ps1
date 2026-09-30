function Register-MT4Realtime {
    <#
    .SYNOPSIS
        Subscribes an MT4 real-time connection to one or more event categories.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [Parameter(Mandatory)][ValidateSet('Ticks','Trades','Users','Symbols','MarginCall')][string[]] $Category,
        [string[]] $Symbol,
        [ValidateRange(1, 3600)][int] $TimeoutSeconds
    )
    if ($Connection.Sink.HasFault) { throw "Realtime connection fault: $($Connection.Sink.Fault.Message)" }
    $streamMethods = @{
        Trades     = 'StreamTrades'
        Users      = 'StreamUserUpdates'
        Symbols    = 'StreamSymbolUpdates'
        MarginCall = 'StreamMarginCallUpdates'
    }
    if (-not $PSBoundParameters.ContainsKey('TimeoutSeconds')) {
        $TimeoutSeconds = if ($Connection.Session -and $Connection.Session.RealtimeTimeoutSeconds) { [int]$Connection.Session.RealtimeTimeoutSeconds } else { 30 }
    }
    $ct = [System.Threading.CancellationToken]::None
    foreach ($c in $Category) {
        if ($c -eq 'Ticks') {
            if (-not $Symbol) { throw '-Symbol is required when subscribing to Ticks.' }
            foreach ($s in $Symbol) {
                $task = [Microsoft.AspNetCore.SignalR.Client.HubConnectionExtensions]::InvokeAsync(
                    $Connection.Sink.Connection, 'SubscribeToTicks', $s, $ct)
                if (-not $task.Wait($TimeoutSeconds * 1000)) {
                    throw "Timed out registering tick subscription after $TimeoutSeconds second(s)."
                }
                [void]$task.GetAwaiter().GetResult()
            }
        } else {
            $Connection.Sink.StartStream($streamMethods[$c])
        }
    }
}
