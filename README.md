# MyWebApi — PowerShell SDK

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/MyWebApi?label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/MyWebApi)
[![Downloads](https://img.shields.io/powershellgallery/dt/MyWebApi?label=downloads)](https://www.powershellgallery.com/packages/MyWebApi)
[![CI](https://github.com/CPlugin/mywebapi.com-sdk-powershell/actions/workflows/ci.yml/badge.svg)](https://github.com/CPlugin/mywebapi.com-sdk-powershell/actions/workflows/ci.yml)

PowerShell 7.4 on .NET 8 client for the MyWebAPI.com trading-platform management API (v2): the full REST surface as idiomatic cmdlets, plus real-time streaming over SignalR.

> **Trademark notice:** third-party trading-platform names and trademarks are the property of their respective owners. This is an independent client library, not affiliated with, endorsed by, or sponsored by any platform vendor.

## Install

The module is published to the [PowerShell Gallery](https://www.powershellgallery.com/packages/MyWebApi) — install it directly, no build step required:

```powershell
Install-Module MyWebApi -Scope CurrentUser
```

Update to the latest version later with `Update-Module MyWebApi`.

### Requirements

- **PowerShell 7.4 on .NET 8** (Windows, Linux, macOS) is the supported runtime for the packaged SignalR assemblies.
- The REST layer and realtime layer are loaded together; an incompatible bundled DLL is a clear import error, not a silently disabled feature. Use the exact supported runtime or a REST-only source tree with an empty lib/ directory.

## Credentials & environments

API keys and trade platforms are created and managed in the **CPlugin Toolbox**:

- Staging — [pre.toolbox.cplugin.com](https://pre.toolbox.cplugin.com)
- Production — [toolbox.cplugin.com](https://toolbox.cplugin.com)

`Connect-MyWebApi` takes a named environment preset (or explicit `-BaseUrl`/`-Authority` for a custom deployment):

| Preset | API base | Authority |
|--------|----------|-----------|
| `Staging` | `https://pre.mywebapi.com` | `https://pre.auth.cplugin.net` |
| `Production` | `https://cloud.mywebapi.com` | `https://auth.cplugin.net` |

## Quickstart

```powershell
Import-Module MyWebApi

# Connect once — the token is acquired and refreshed automatically. Keep the returned
# session when using more than one API target; every cmdlet accepts -Connection.
$secret = ConvertTo-SecureString $env:WEBAPI_CLIENT_SECRET -AsPlainText -Force
$session = Connect-MyWebApi -Environment Staging -ClientId $env:WEBAPI_CLIENT_ID -ClientSecret $secret

# Discover the trade platform id(s) your credentials can access.
$tp = (Get-MyWebApiTradePlatform -Connection $session)[0].id

Get-MT4UserRecordGet     -Connection $session -TradePlatform $tp -Login 42   # cached (pump) read
Get-MT4UserRecordRequest -Connection $session -TradePlatform $tp -Login 42   # live (manager) read
Get-MT4UsersRequest      -Connection $session -TradePlatform $tp -All        # follow every page

Disconnect-MyWebApi -Connection $session
```

If you have exactly one trade platform, `Get-MyWebApiTradePlatform` returns it directly; with several, pick the id you need. Omit -Connection only when deliberately using the optional default session.

Each connection validates HTTPS and same-origin OAuth discovery. HTTP is accepted only for an explicitly enabled loopback test endpoint (-AllowInsecureLoopback). Writes are never retried automatically; GET/HEAD/OPTIONS use only a bounded retry policy.

## Cmdlet naming

The verb comes from the HTTP method (`Get`, `Invoke`, `Update`, `Set`, `Remove`); the noun is the platform (`MT4`/`MT5`) plus the API action name verbatim. Cached vs. live variants keep the API's own `Get`/`Request` suffix, so the cmdlets map one-to-one onto the REST endpoints. Discover them with:

```powershell
Get-Command -Module MyWebApi                 # everything
Get-Command -Module MyWebApi -Verb Get       # reads
Get-Help Get-MT4UserRecordGet -Full          # per-cmdlet help
```

## Pagination

List endpoints accept `-Limit`/`-Cursor`, or `-All` to walk every page transparently:

```powershell
Get-MT4TradesGet -Connection $session -TradePlatform $tp -All | Where-Object { $_.profit -lt 0 }
```

## Real-time streaming

```powershell
$rt = Connect-MT4Realtime -Session $session -TradePlatform $tp

# Ticks use subscribe + callback (needs a symbol); everything else is a server stream.
Register-MT4Realtime -Connection $rt -Category Ticks -Symbol EURUSD
Register-MT4Realtime -Connection $rt -Category Trades, Users, Symbols, MarginCall

Receive-MT4Realtime -Connection $rt -TimeoutSeconds 30 |
    Where-Object Method -eq 'OnTick' |
    ForEach-Object { '{0}  bid={1} ask={2}' -f $_.Payload.symbol, $_.Payload.bid, $_.Payload.ask }

Disconnect-MT4Realtime -Connection $rt
```

MT5 exposes the same shape via `Connect-MT5Realtime` / `Register-MT5Realtime` / `Receive-MT5Realtime` / `Disconnect-MT5Realtime`.

## Examples

Runnable scripts live in [`examples/`](examples/):

- `01-connect-and-read.ps1` — connect, discover a platform, read (cached / live / paged)
- `02-realtime-ticks.ps1` — stream live ticks
- `03-trading-terminal.ps1` — live prices + open/close an order (dry-run by default; `-Live` places real orders)

Copy `.env.example`, fill in your `WEBAPI_CLIENT_ID` / `WEBAPI_CLIENT_SECRET`, and run any example.

## Development (from source)

You only need this to work on the SDK itself — consumers install from the Gallery.

```bash
git clone https://github.com/CPlugin/mywebapi.com-sdk-powershell
cd mywebapi.com-sdk-powershell
./build.ps1        # restore SignalR lib, regenerate cmdlets, lint (PSScriptAnalyzer), test (Pester)
```

REST cmdlets are generated from `spec/v2.json`; the real-time layer and session/auth are hand-written. See `PUBLISHING.md` for the release process.

## License

MIT — see [`LICENSE`](LICENSE).
