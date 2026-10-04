# MyWebApi — PowerShell SDK

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/MyWebApi?label=PowerShell%20Gallery)](https://www.powershellgallery.com/packages/MyWebApi)
[![Downloads](https://img.shields.io/powershellgallery/dt/MyWebApi?label=downloads)](https://www.powershellgallery.com/packages/MyWebApi)
[![CI](https://github.com/CPlugin/mywebapi.com-sdk-powershell/actions/workflows/ci.yml/badge.svg)](https://github.com/CPlugin/mywebapi.com-sdk-powershell/actions/workflows/ci.yml)

PowerShell 7.4 on .NET 8 client for the MyWebAPI.com trading-platform management API (v2): the full REST surface as idiomatic cmdlets, plus real-time streaming over SignalR.

The WebAPI works with MetaTrader 4 and MetaTrader 5 servers, so an administrator can script a broker's trade server from PowerShell on Windows, Linux or macOS without installing native platform libraries.

- Product and sign-up: <https://mywebapi.com>
- API reference: <https://cplugin.com/docs/webapi> · interactive: <https://cloud.mywebapi.com/swagger>
- Pricing: <https://cplugin.com/docs/pricing-and-terms>

> **Trademarks:** MetaTrader, MT4, MT5 and MetaQuotes are trademarks or registered trademarks of MetaQuotes Ltd. This is an independent client library, not affiliated with, endorsed by, or sponsored by MetaQuotes Ltd. All other trademarks are the property of their respective owners.

## What brokers do with it

Typical back-office tasks, each with the cmdlet that performs it. `$session` comes from `Connect-MyWebApi` and `$tp` is the trade platform id (see [Quickstart](#quickstart)); `$c = @{ Connection = $session; TradePlatform = $tp }` is splatted to keep the lines short.

**List open positions of a group** (MT4 `AdmTradesRequest`, MT5 `PositionByGroup`):

```powershell
$c = @{ Connection = $session; TradePlatform = $tp }
Get-MT4AdmTradesRequest @c -Group real-usd -OpenOnly
Get-MT5PositionByGroup  @c -Mask 'real\*' -All |
    Format-Table login, symbol, volume, profit
```

**Stream trades in real time** (SignalR; the MT4 hub streams trades, ticks, account and symbol changes and margin calls):

```powershell
$rt = Connect-MT4Realtime -Session $session -TradePlatform $tp
Register-MT4Realtime -Connection $rt -Category Trades
Receive-MT4Realtime -Connection $rt -TimeoutSeconds 60 |
    Where-Object Method -eq 'StreamTrades' |
    ForEach-Object { '{0} #{1} {2} {3}' -f $_.Payload.kind, $_.Payload.order, $_.Payload.login, $_.Payload.symbol }
```

**Open an account from a CRM** (`UserRecordNew`, then `UserPasswordSet`):

```powershell
$user = Invoke-MT4UserRecordNew @c -IdempotencyKey $crmRequestId -Body @{
    login = 0; group = 'real-usd'; name = 'John Smith'; email = 'john@example.com'; leverage = 100 }
Invoke-MT4UserPasswordSet @c -Login $user.login -Body $newPassword
```

**Post a deposit or a withdrawal** (`TradeTransaction` balance operation; a negative amount withdraws):

```powershell
Invoke-MT4TradeTransaction @c -IdempotencyKey $paymentId -Body @{
    tradeTransactionType = 'BrBalance'; tradeCommand = 'Balance'
    orderBy = 1001; price = 500; comment = 'Deposit #8812' }
```

**Move an account to another group or change its leverage** (JSON Merge Patch, MT4 and MT5):

```powershell
Update-MT4UserRecord @c -Login 1001  -Body @{ group = 'real-vip'; leverage = 200 }
Update-MT5UserRecord @c -Login 50001 -Body @{ leverage = 200 }
```

**Read trade history for reports and statements** (`TradesUserHistory`, MT5 `DealByGroup`):

```powershell
Get-MT4TradesUserHistory @c -Login 1001 -FromTime '2026-09-01T00:00:00Z' -ToTime '2026-10-01T00:00:00Z' |
    Export-Csv statement-1001.csv
Get-MT5DealByGroup @c -Mask 'real\*' -All | Export-Csv deals.csv
```

**Watch margin levels** (cached snapshot of every account; the live stream is `Register-MT4Realtime -Category MarginCall`):

```powershell
Get-MT4MarginsGet @c |
    Where-Object { $_.level -gt 0 -and $_.level -lt 100 } |
    Format-Table login, group, balance, equity, margin, level
```

**Change symbol settings, for example swaps** (`SymbolConfig` on MT4, `SymbolRecord` on MT5):

```powershell
Update-MT4SymbolConfig @c -Symbol EURUSD -Body @{ swapLong = -6.1; swapShort = 1.2 }
Update-MT5SymbolRecord @c -Symbol EURUSD -Body @{ swapLong = -6.1; swapShort = 1.2 }
```

Every other endpoint (trading groups, server configuration, backups, journal, charts, news, plugins) has its own cmdlet — `Get-Command -Module MyWebApi` lists them; see also the [API reference](https://cplugin.com/docs/webapi).

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

Each connection validates HTTPS and same-origin OAuth discovery. HTTP is accepted only for an explicitly enabled loopback test endpoint (-AllowInsecureLoopback). Writes are never retried automatically; GET/HEAD/OPTIONS use only a bounded retry policy (see [Timeouts and retries](#timeouts-and-retries)).

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

## Timeouts and retries

Every REST cmdlet takes `-RequestTimeout` (seconds, 1–300): how long the server waits for the trading platform before it answers. It is sent as the `X-Request-Timeout` header. Set a default for a whole session with `Connect-MyWebApi -RequestTimeout`; a cmdlet's own value wins. Without either, the server applies the operation's default — trade 5 s, read 10 s, change 15 s, history/report 30 s, server maintenance 60 s (`Get-Help <cmdlet> -Parameter RequestTimeout` shows the value for each cmdlet).

The HTTP call itself waits longer than the server: the requested (or default) server timeout plus 30 s, so you get the server's answer rather than an ambiguous client-side abort. An `-HttpTimeoutSeconds` you set on `Connect-MyWebApi` is a hard cap for calls without an explicit `-RequestTimeout`.

When the platform does not answer in time, the cmdlet throws a terminating error. `FullyQualifiedErrorId` is `MyWebApiError,<code>`; `$_.TargetObject` (and `$_.Exception.Data`) carries `Code`, `Outcome` (the `X-Request-Outcome` response header), `Retryable`, `RequestTimeoutApplied`, `ActivityId`, `IdempotencyKey`, and a `Guidance` text that is also `$_.ErrorDetails.RecommendedAction`.

| Code | Outcome | Meaning | What to do |
|------|---------|---------|------------|
| `Timeout` | `timeout` | A read did not finish in time. Nothing was changed. | Safe to repeat; allow more time with `-RequestTimeout`. |
| `OutcomeUnknown` | `unknown` | A trade or change did not finish in time and **may still be applied**. | Never repeat blindly. Repeat with the **same** `-IdempotencyKey` to get the original result, or check the result first. |
| `OutcomeUnknown` | `in-progress` | A request with the same `Idempotency-Key` is still running; this repeat was not executed. | Repeat later with the same key. |
| `Busy` | `not-started` | Refused before it reached the platform. Nothing was changed. | Safe to repeat after a short pause. |
| `Validation` | — | E.g. a timeout outside 1–300 s. | Fix the request. |

If no HTTP response arrives at all within the deadline, the error id is `MyWebApiHttpTimeout` with `TargetObject.Source = 'client'`; for a write its `Outcome` is `unknown` and the same rule applies.

Retries: GET/HEAD/OPTIONS are retried automatically (at most `-MaxGetRetries`, default 2) on transport failures, HTTP 408/425/429/5xx and `Busy`; a `Timeout` is not retried automatically, because the platform is slow and only you know whether to wait longer. **Writes are never retried**, with or without an Idempotency-Key.

```powershell
$key = [guid]::NewGuid().ToString()
try {
    Invoke-MT4TradeTransaction -TradePlatform $tp -Body $order -IdempotencyKey $key -RequestTimeout 10
} catch {
    if ($_.TargetObject.Code -eq 'OutcomeUnknown') {
        Start-Sleep -Seconds 2
        # Same key: returns the original result instead of placing a second order.
        Invoke-MT4TradeTransaction -TradePlatform $tp -Body $order -IdempotencyKey $key
    } else { throw }
}
```

Real-time hub calls addressed to a trading platform (and the v2 hub connect) are failed by the server after 60 s; streams are not affected. `-RealtimeTimeoutSeconds` / `-TimeoutSeconds` above that therefore do not extend those calls.

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

You only need this to work on the SDK itself — consumers install from the Gallery. The repository `global.json` pins the build SDK to .NET 8.0.425 with SDK roll-forward disabled; `dotnet --version` must report `8.0.425` before running the build.

```bash
git clone https://github.com/CPlugin/mywebapi.com-sdk-powershell
cd mywebapi.com-sdk-powershell
dotnet --version   # 8.0.425, selected from global.json
./build.ps1        # restore SignalR lib, regenerate cmdlets, lint (PSScriptAnalyzer), test (Pester)
```

REST cmdlets are generated from `spec/v2.json`; the real-time layer and session/auth are hand-written. See `PUBLISHING.md` for the release process.

## License

MIT — see [`LICENSE`](LICENSE).
