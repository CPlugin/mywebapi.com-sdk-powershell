function Connect-MT5Realtime {
    <# .SYNOPSIS Opens a real-time streaming connection to the MT5 hub. #>
    [CmdletBinding()]
    param(
        [Parameter()][string] $TradePlatform,
        [Parameter()][object] $Session
    )
    Open-MyWebApiRealtimeConnection -Hub 'mt5' -TradePlatform $TradePlatform -Connection $Session
}
