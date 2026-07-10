# MyWebApi (PowerShell SDK)

PowerShell 7.4+ client for the trading platform management WebAPI (v2): REST + real-time streaming.

> **Trademark notice:** third-party trading platform names and trademarks are the property of their respective owners. This is an independent client library, not affiliated with, endorsed by, or sponsored by any platform vendor.

## Requirements

- PowerShell 7.4 or later (Windows, Linux, macOS).

## Install

```powershell
Install-Module MyWebApi -Scope CurrentUser
```

## Credentials & environments

API keys and trade platforms are created and managed in the **CPlugin Toolbox**:

- Staging: <https://pre.toolbox.cplugin.com>
- Production: <https://toolbox.cplugin.com>

`Connect-MyWebApi` accepts a named environment preset (or explicit `-BaseUrl`/`-Authority` for a custom deployment):

| Preset | API base | Authority |
|--------|----------|-----------|
| `Staging` | `https://pre.mywebapi.com` | `https://pre.auth.cplugin.net` |
| `Production` | `https://cloud.mywebapi.com` | `https://auth.cplugin.net` |

## Quickstart

```powershell
Import-Module MyWebApi

$secret = ConvertTo-SecureString $env:WEBAPI_CLIENT_SECRET -AsPlainText -Force
Connect-MyWebApi -Environment Staging -ClientId $env:WEBAPI_CLIENT_ID -ClientSecret $secret

# Discover your trade platform GUID(s):
$tp = (Get-MyWebApiTradePlatform)[0].id

Get-MT4UserRecordGet -TradePlatform $tp -Login 42        # cached read
Get-MT4UserRecordRequest -TradePlatform $tp -Login 42    # live read
Get-MT4UsersRequest -TradePlatform $tp -All              # follow all pages
```

## Cmdlet naming

Verb comes from the HTTP method (`Get`, `Invoke`, `Update`, `Set`, `Remove`); the noun is the platform (`MT4`/`MT5`) plus the API action name verbatim. Cached vs live variants are distinguished by the `Get`/`Request` suffix, matching the REST API.

## Real-time streaming

```powershell
$rt = Connect-MT4Realtime
Register-MT4Realtime -Connection $rt -Category Ticks -Symbol EURUSD   # ticks (needs -Symbol)
Register-MT4Realtime -Connection $rt -Category Trades,Users,Symbols,MarginCall  # server streams
Receive-MT4Realtime -Connection $rt -TimeoutSeconds 10 | ForEach-Object { $_.Payload }
Disconnect-MT4Realtime -Connection $rt
```

## Development

```bash
./build.ps1          # restore lib, generate cmdlets, lint, test
```

## License

MIT. See `LICENSE`.
