function Connect-MT5Realtime {
    <#
    .SYNOPSIS
        Opens a real-time streaming connection to the MT5 hub.
    .DESCRIPTION
        Opens a SignalR connection to /hubs/mt5/v2 for one trade platform and registers the
        OnTick and OnTicksBatch handlers, so subscriptions made with Register-MT5Realtime
        -Category Ticks are delivered as OnTick events and -Category TicksBatch as OnTicksBatch
        events by Receive-MT5Realtime. The trade platform is bound at connect time; call this
        cmdlet again after a disconnect to obtain a fresh token.
    .PARAMETER TradePlatform
        Trade platform id (GUID). Defaults to -DefaultTradePlatform of the session.
    .PARAMETER Session
        Session returned by Connect-MyWebApi. Omit only when using the default session.
    .EXAMPLE
        $rt = Connect-MT5Realtime -Session $session -TradePlatform $tp
    #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][object] $Session
    )
    $rt = Open-MyWebApiRealtimeConnection -Hub 'mt5' -TradePlatform $TradePlatform -Connection $Session
    # The MT5 v2 hub pushes subscribed ticks as OnTick and batched ticks as OnTicksBatch;
    # register both handlers once per connection.
    $rt.Sink.On('OnTick')
    $rt.Sink.On('OnTicksBatch')
    $rt
}
