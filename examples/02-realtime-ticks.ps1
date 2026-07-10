Import-Module ./src/MyWebApi/MyWebApi.psd1 -Force
. "$PSScriptRoot/_shared.ps1"

Connect-FromEnv
$tp = Resolve-TradePlatform

$rt = Connect-MT4Realtime -TradePlatform $tp
Register-MT4Realtime -Connection $rt -Category Ticks -Symbol 'EURUSD'

# Stream 10 seconds of ticks:
Receive-MT4Realtime -Connection $rt -TimeoutSeconds 10 |
    Where-Object Method -eq 'OnTick' |
    ForEach-Object { "{0} bid={1}" -f $_.Payload.symbol, $_.Payload.bid }

Disconnect-MT4Realtime -Connection $rt
Disconnect-MyWebApi
