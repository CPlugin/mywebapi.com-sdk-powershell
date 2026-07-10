# SDK Examples — MyWebApi (PowerShell)

Three progressive examples showing how to use the `MyWebApi` PowerShell module. Each builds on the previous one, adding a new capability.

> **WARNING — Example 03 with `-Live`**
> Running `pwsh examples/03-trading-terminal.ps1 -Live` places **real market orders** on the configured MT4 trade server. Only do this against a demo or test account. The default dry-run mode is safe and prints the request body without sending anything.

---

## Prerequisites

Run from the repository root so the relative `Import-Module ./src/MyWebApi/MyWebApi.psd1` path in each script resolves.

The real-time examples (02, 03) need the module's SignalR client library restored/packaged — see `scripts/restore-lib.sh` / `build.ps1` in the repo root. A fully built module (`./build.ps1`) covers this.

---

## Getting started (minimal friction)

You need **credentials only** — no manual platform lookup required.

```powershell
Copy-Item .env.example .env
# Fill in WEBAPI_CLIENT_ID and WEBAPI_CLIENT_SECRET
# WEBAPI_ENV defaults to Staging — no other changes needed

# Load .env into the current session (pwsh has no built-in .env loader):
Get-Content .env | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $k, $v = $_ -split '=', 2
    Set-Item -Path "Env:$k" -Value $v
}

pwsh examples/01-connect-and-read.ps1
```

What happens on first run:

- **One trade platform** on your account → it is selected automatically.
- **Multiple trade platforms** → `Resolve-TradePlatform` (in `_shared.ps1`) lists every platform with its id and name, then throws. Set `WEBAPI_TRADE_PLATFORM=<id>` in your `.env` and re-run.
- **No trade platforms** → a message explains how to create one in the Toolbox (staging <https://pre.toolbox.cplugin.com> · prod <https://toolbox.cplugin.com>).

---

## Environment variables

Configuration is templated in `.env.example` at the repo root. To set up:

```powershell
Copy-Item .env.example .env
# then edit .env and fill in your credentials
```

Your `.env` file is gitignored and will never be committed. `.env.example` is committed so others can copy it as a starting template.

### Environment preset

`WEBAPI_ENV` selects a named preset (`Staging`, default, or `Production`) resolved by `Connect-MyWebApi -Environment`. There is no separate base-URL/authority override for the examples — use the e2e harness (`e2e/_Setup.ps1`) if you need a custom deployment.

### Required credentials

Create API keys (client ID and client secret) in the **Toolbox**:
- **Staging:** <https://pre.toolbox.cplugin.com>
- **Production:** <https://toolbox.cplugin.com>

Fill in `WEBAPI_CLIENT_ID` and `WEBAPI_CLIENT_SECRET` with the credentials from the Toolbox. Both are required.

### Optional variables

- `WEBAPI_TRADE_PLATFORM` — Platform id. **Auto-selected when you have exactly one platform.** Set this explicitly only if you have multiple platforms and want to pick a specific one.
- `WEBAPI_SYMBOL` — Symbol to trade/stream (default: `EURUSD`).
- `WEBAPI_VOLUME` — Volume in MT4 internal units for example 03 (default: `10` = 0.1 lot; 1 lot = 100 units).

All examples throw a clear error message if a required variable is missing or if manual platform selection is needed.

---

## Example 01 — Connect and Read (`01-connect-and-read.ps1`)

**What it shows:** platform auto-selection via `Resolve-TradePlatform`, OAuth2 auth, REST cmdlets, cached vs live reads, paged listing.

```powershell
Connect-FromEnv
$tp = Resolve-TradePlatform

Get-MT4UserRecordGet -TradePlatform $tp -Login 42        # cached (pump) read
Get-MT4UserRecordRequest -TradePlatform $tp -Login 42    # live (manager) read
Get-MT4UsersRequest -TradePlatform $tp -All | Select-Object -First 5   # paged, follows all cursors
```

Run:

```powershell
pwsh examples/01-connect-and-read.ps1
```

---

## Example 02 — Realtime Ticks (`02-realtime-ticks.ps1`)

**What it shows:** SignalR real-time connection, tick subscription, streamed payloads via `Receive-MT4Realtime`.

Opens a connection to the MT4 real-time hub, subscribes to tick updates for the configured symbol, and prints each tick as it arrives for 10 seconds.

```powershell
pwsh examples/02-realtime-ticks.ps1
```

Override the symbol via `WEBAPI_SYMBOL` in `.env`, or:

```powershell
$env:WEBAPI_SYMBOL = 'USDJPY'
pwsh examples/02-realtime-ticks.ps1
```

---

## Example 03 — Trading Terminal (`03-trading-terminal.ps1`)

**What it shows:** tick subscription + open-trades listing + full order lifecycle (open, close).

1. Subscribes to ticks and waits for the first one to get a fresh bid/ask.
2. Lists all open trades (`-All`, follows every cursor).
3. Opens a market Buy order at the current ask price.
4. Closes the same order at the current bid price.

**Dry-run (default — no orders placed):**

```powershell
pwsh examples/03-trading-terminal.ps1
```

This prints the exact JSON body each trade request would send, then exits without touching the server.

**Live mode — places REAL orders:**

```powershell
pwsh examples/03-trading-terminal.ps1 -Live
```

Only use `-Live` on a demo/test MT4 server. The volume defaults to 10 internal units (0.1 lot). Override with `WEBAPI_VOLUME` if needed.

---

## Running the SDK test suite

```powershell
./build.ps1
```

Builds, validates the manifest, runs PSScriptAnalyzer, and runs the unit test suite in `tests/` (not the gated e2e suite in `e2e/` — see `e2e/README.md` for that).
