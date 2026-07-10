function Register-MT4Realtime {
    <#
    .SYNOPSIS
        Subscribes an MT4 real-time connection to one or more event categories.
    .DESCRIPTION
        Ticks use the subscribe/callback model (SubscribeToTicks -> OnTick) and require -Symbol.
        Trades, Users, Symbols, and MarginCall are consumed as server streams. All events surface
        through Receive-MT4Realtime.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [Parameter(Mandatory)][ValidateSet('Ticks','Trades','Users','Symbols','MarginCall')][string[]] $Category,
        [string[]] $Symbol
    )
    $streamMethods = @{
        Trades     = 'StreamTrades'
        Users      = 'StreamUserUpdates'
        Symbols    = 'StreamSymbolUpdates'
        MarginCall = 'StreamMarginCallUpdates'
    }
    $ct = [System.Threading.CancellationToken]::None
    foreach ($c in $Category) {
        if ($c -eq 'Ticks') {
            if (-not $Symbol) { throw '-Symbol is required when subscribing to Ticks.' }
            foreach ($s in $Symbol) {
                $task = [Microsoft.AspNetCore.SignalR.Client.HubConnectionExtensions]::InvokeAsync(
                    $Connection.Sink.Connection, 'SubscribeToTicks', [object[]]@($s), $ct)
                $task.GetAwaiter().GetResult()
            }
        } else {
            $Connection.Sink.StartStream($streamMethods[$c])
        }
    }
}
