function Unregister-MT4Realtime {
    <#
    .SYNOPSIS
        Stops tick subscriptions of one or more symbols on an MT4 real-time connection.
    .DESCRIPTION
        Removes per-symbol subscriptions made with Register-MT4Realtime. Category Ticks removes
        the per-tick subscription (UnsubscribeFromTicks), TicksBatch the batched one
        (UnsubscribeFromTicksBatch); the server keeps the two models apart, so both can be
        removed for the same symbol. Events of the removed subscription are no longer pushed;
        payloads already queued are still returned by Receive-MT4Realtime. The connection
        itself stays open.
    .PARAMETER Connection
        Connection object returned by Connect-MT4Realtime.
    .PARAMETER Category
        Subscription model to remove: Ticks or TicksBatch. Defaults to Ticks.
    .PARAMETER Symbol
        Symbol or symbols whose subscription is removed.
    .PARAMETER TimeoutSeconds
        How long to wait for the hub to confirm the removal, in seconds (1-3600).
        Defaults to the session's RealtimeTimeoutSeconds, or 30.
    .EXAMPLE
        Unregister-MT4Realtime -Connection $rt -Symbol EURUSD
    .EXAMPLE
        Unregister-MT4Realtime -Connection $rt -Category TicksBatch -Symbol EURUSD
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [ValidateSet('Ticks','TicksBatch')][string] $Category = 'Ticks',
        [Parameter(Mandatory)][string[]] $Symbol,
        [ValidateRange(1, 3600)][int] $TimeoutSeconds
    )
    if ($Connection.Sink.HasFault) { throw "Realtime connection fault: $($Connection.Sink.Fault.Message)" }
    if (-not $PSBoundParameters.ContainsKey('TimeoutSeconds')) {
        $TimeoutSeconds = if ($Connection.Session -and $Connection.Session.RealtimeTimeoutSeconds) { [int]$Connection.Session.RealtimeTimeoutSeconds } else { 30 }
    }
    $method = if ($Category -eq 'TicksBatch') { 'UnsubscribeFromTicksBatch' } else { 'UnsubscribeFromTicks' }
    $what = if ($Category -eq 'TicksBatch') { 'the tick batch subscription' } else { 'the tick subscription' }
    $ct = [System.Threading.CancellationToken]::None
    foreach ($s in $Symbol) {
        $task = [Microsoft.AspNetCore.SignalR.Client.HubConnectionExtensions]::InvokeAsync(
            $Connection.Sink.Connection, $method, $s, $ct)
        if (-not $task.Wait($TimeoutSeconds * 1000)) {
            throw "Timed out removing $what of '$s' after $TimeoutSeconds second(s)."
        }
        [void]$task.GetAwaiter().GetResult()
    }
}
