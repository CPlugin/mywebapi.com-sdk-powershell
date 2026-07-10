function Connect-MT4Realtime {
    <# .SYNOPSIS Opens a real-time streaming connection to the MT4 hub. #>
    [CmdletBinding()]
    param([Parameter()][string] $TradePlatform)
    Open-MyWebApiRealtimeConnection -Hub 'mt4' -TradePlatform $TradePlatform
}
