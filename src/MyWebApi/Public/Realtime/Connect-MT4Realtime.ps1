function Connect-MT4Realtime {
    <#
    .SYNOPSIS
        Opens a real-time streaming connection to the MT4 hub.
    .DESCRIPTION
        Opens a SignalR connection to /hubs/mt4/v2 for one trade platform and registers the
        OnTicksBatch handler, so subscriptions made with Register-MT4Realtime -Category
        TicksBatch are delivered as OnTicksBatch events by Receive-MT4Realtime. The per-tick
        OnTick handler is registered by the connection itself. The trade platform is bound at
        connect time; call this cmdlet again after a disconnect to obtain a fresh token.
    .PARAMETER TradePlatform
        Trade platform id (GUID). Defaults to -DefaultTradePlatform of the session.
    .PARAMETER Session
        Session returned by Connect-MyWebApi. Omit only when using the default session.
    .EXAMPLE
        $rt = Connect-MT4Realtime -Session $session -TradePlatform $tp
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][object] $Session
    )
    $rt = Open-MyWebApiRealtimeConnection -Hub 'mt4' -TradePlatform $TradePlatform -Connection $Session
    # The MT4 v2 hub pushes batched ticks as the OnTicksBatch event; register the handler once per connection.
    $rt.Sink.On('OnTicksBatch')
    $rt
}
