Import-Module ./src/MyWebApi/MyWebApi.psd1 -Force
. "$PSScriptRoot/_shared.ps1"

Connect-FromEnv
$tp = Resolve-TradePlatform

# Cached (pump) read:
Get-MT4UserRecordGet -TradePlatform $tp -Login 42

# Live (manager) read:
Get-MT4UserRecordRequest -TradePlatform $tp -Login 42

# Paged list, following all cursors:
Get-MT4UsersRequest -TradePlatform $tp -All | Select-Object -First 5

Disconnect-MyWebApi
