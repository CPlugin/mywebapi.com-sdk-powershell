function Register-MT5Realtime {
    <#
    .SYNOPSIS
        Subscribes an MT5 real-time connection to one or more event categories.
    .DESCRIPTION
        Ticks use a per-symbol callback subscription: every symbol is subscribed on the hub and
        arrives as an OnTick event from Receive-MT5Realtime. TicksBatch subscribes the same way
        but the server accumulates ticks and pushes them as one OnTicksBatch payload per symbol;
        a batched symbol receives no per-tick OnTick. Margin calls are a single server stream,
        started once for the connection.
    .PARAMETER Connection
        Connection object returned by Connect-MT5Realtime.
    .PARAMETER Category
        Event categories to subscribe to: Ticks, TicksBatch or MarginCall.
    .PARAMETER Symbol
        Symbol or symbols to receive ticks for. Required when Category includes Ticks or TicksBatch.
    .PARAMETER IntervalMs
        Longest wait of a tick for its batch, in milliseconds (20-60000). Defaults to 200;
        applies to TicksBatch only.
    .PARAMETER MaxBatchSize
        Maximum ticks in one OnTicksBatch payload (1-10000). Defaults to 200; applies to
        TicksBatch only.
    .PARAMETER TimeoutSeconds
        How long to wait for the hub to confirm a tick subscription, in seconds (1-3600).
        Defaults to the session's RealtimeTimeoutSeconds, or 30.
    .EXAMPLE
        Register-MT5Realtime -Connection $rt -Category Ticks -Symbol EURUSD
    .EXAMPLE
        Register-MT5Realtime -Connection $rt -Category Ticks, MarginCall -Symbol EURUSD, XAUUSD
    .EXAMPLE
        Register-MT5Realtime -Connection $rt -Category TicksBatch -Symbol EURUSD -IntervalMs 500 -MaxBatchSize 100
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [Parameter(Mandatory)][ValidateSet('Ticks','TicksBatch','MarginCall')][string[]] $Category,
        [string[]] $Symbol,
        [ValidateRange(20, 60000)][int] $IntervalMs = 200,
        [ValidateRange(1, 10000)][int] $MaxBatchSize = 200,
        [ValidateRange(1, 3600)][int] $TimeoutSeconds
    )
    if ($Connection.Sink.HasFault) { throw "Realtime connection fault: $($Connection.Sink.Fault.Message)" }
    if (-not $PSBoundParameters.ContainsKey('TimeoutSeconds')) {
        $TimeoutSeconds = if ($Connection.Session -and $Connection.Session.RealtimeTimeoutSeconds) { [int]$Connection.Session.RealtimeTimeoutSeconds } else { 30 }
    }
    $ct = [System.Threading.CancellationToken]::None
    foreach ($c in $Category) {
        if ($c -eq 'Ticks' -or $c -eq 'TicksBatch') {
            if (-not $Symbol) { throw "-Symbol is required when subscribing to $c." }
            foreach ($s in $Symbol) {
                if ($c -eq 'Ticks') {
                    $task = [Microsoft.AspNetCore.SignalR.Client.HubConnectionExtensions]::InvokeAsync(
                        $Connection.Sink.Connection, 'SubscribeToTicks', $s, $ct)
                    $failure = "Timed out registering tick subscription for '$s' after $TimeoutSeconds second(s)."
                } else {
                    $task = [Microsoft.AspNetCore.SignalR.Client.HubConnectionExtensions]::InvokeAsync(
                        $Connection.Sink.Connection, 'SubscribeToTicksBatch', $s, $IntervalMs, $MaxBatchSize, $ct)
                    $failure = "Timed out registering the tick batch subscription of '$s' after $TimeoutSeconds second(s)."
                }
                if (-not $task.Wait($TimeoutSeconds * 1000)) {
                    throw $failure
                }
                [void]$task.GetAwaiter().GetResult()
            }
        } else {
            switch ($c) {
                'MarginCall' { $Connection.Sink.StartStream('StreamMarginCallUpdates') }
            }
        }
    }
}
