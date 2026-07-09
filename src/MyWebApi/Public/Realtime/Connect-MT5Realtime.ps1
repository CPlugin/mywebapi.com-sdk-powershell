function Connect-MT5Realtime {
    <# .SYNOPSIS Opens a real-time streaming connection to the MT5 hub. #>
    [CmdletBinding()]
    param([Parameter()][string] $TradePlatform)
    New-MyWebApiRealtime -Hub 'mt5' -TradePlatform $TradePlatform
}
