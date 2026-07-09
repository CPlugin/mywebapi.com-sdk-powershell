function Subscribe-MT5Realtime {
    <# .SYNOPSIS Subscribes the MT5 connection to one or more event categories. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [Parameter(Mandatory)][ValidateSet('Ticks','Trades','Users','Symbols','MarginCall')][string[]] $Category,
        [string[]] $Symbol,
        [long[]] $Login
    )
    $method = @{ Ticks='SubscribeToTicks'; Trades='SubscribeToTrades'; Users='SubscribeToUsers'; Symbols='SubscribeToSymbols'; MarginCall='SubscribeToMarginCalls' }
    foreach ($c in $Category) {
        $arg = switch ($c) { 'Ticks' { ,$Symbol } 'Symbols' { ,$Symbol } 'Users' { ,$Login } default { @() } }
        $task = [Microsoft.AspNetCore.SignalR.Client.HubConnectionExtensions]::InvokeCoreAsync(
            $Connection.Sink.Connection, $method[$c], [object[]]$arg, [System.Threading.CancellationToken]::None)
        $task.GetAwaiter().GetResult()
    }
}
