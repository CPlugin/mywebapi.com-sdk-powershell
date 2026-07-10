# Shared helper for examples: connect using env vars and resolve a trade platform.
# Env: WEBAPI_ENV (Staging|Production, default Staging), WEBAPI_CLIENT_ID,
#      WEBAPI_CLIENT_SECRET, WEBAPI_TRADE_PLATFORM (optional).
function Connect-FromEnv {
    if (-not $env:WEBAPI_CLIENT_ID -or -not $env:WEBAPI_CLIENT_SECRET) {
        throw 'Set WEBAPI_CLIENT_ID and WEBAPI_CLIENT_SECRET (create keys in the Toolbox).'
    }
    $envName = if ($env:WEBAPI_ENV) { $env:WEBAPI_ENV } else { 'Staging' }
    $secret = ConvertTo-SecureString $env:WEBAPI_CLIENT_SECRET -AsPlainText -Force
    Connect-MyWebApi -Environment $envName -ClientId $env:WEBAPI_CLIENT_ID -ClientSecret $secret
}

function Resolve-TradePlatform {
    if ($env:WEBAPI_TRADE_PLATFORM) { return $env:WEBAPI_TRADE_PLATFORM }
    $platforms = Get-MyWebApiTradePlatform
    switch (@($platforms).Count) {
        0 { throw 'No trade platforms on this account. Create one in the Toolbox (https://toolbox.cplugin.com).' }
        1 { return $platforms[0].id }
        default {
            Write-Host 'Multiple trade platforms — set WEBAPI_TRADE_PLATFORM to one of:'
            $platforms | ForEach-Object { Write-Host ("  {0}  {1}" -f $_.id, $_.name) }
            throw 'WEBAPI_TRADE_PLATFORM is required when more than one platform exists.'
        }
    }
}
