# E2E Test Suite — MyWebApi (PowerShell SDK)

End-to-end tests that exercise the **real running WebAPI** server: OAuth token acquisition, REST v2 envelope unwrapping, terminating-error propagation, pagination, and SignalR tick streaming.

Every case is **gated**: without the opt-in flag and credentials, `Invoke-Pester ./e2e` produces only `Skipped` results — never failures — so it stays green on CI and offline.

## Quick start

```powershell
# 1. Copy the template and fill in your manager credentials
Copy-Item .env.example .env   # gitignored — never commit this file

# 2. Populate .env
WEBAPI_E2E=1
WEBAPI_ENV=Staging
WEBAPI_CLIENT_ID=my-manager-client
WEBAPI_CLIENT_SECRET=secret-here

# 3. Load .env into the current session, then run
Get-Content .env | Where-Object { $_ -match '=' -and $_ -notmatch '^#' } | ForEach-Object {
    $k, $v = $_ -split '=', 2
    Set-Item -Path "Env:$k" -Value $v
}
Invoke-Pester ./e2e -Output Detailed
```

## Environment variables

### Required

| Variable | Example | Description |
|---|---|---|
| `WEBAPI_E2E` | `1` | Opt-in flag — must be exactly `1` to enable the suite |
| `WEBAPI_CLIENT_ID` | `my-client` | OAuth2 `client_id` |
| `WEBAPI_CLIENT_SECRET` | `secret` | OAuth2 `client_secret` |

### Connection target — pick ONE

| Variable | Example | Description |
|---|---|---|
| `WEBAPI_ENV` | `Staging` | Named preset (`Staging` default, or `Production`) — used when `WEBAPI_BASE_URL`/`WEBAPI_AUTHORITY` are unset |
| `WEBAPI_BASE_URL` + `WEBAPI_AUTHORITY` | `https://pre.mywebapi.com` / `https://pre.auth.cplugin.net` | Custom deployment — both must be set together to take precedence over `WEBAPI_ENV` |

### Optional

| Variable | Default | Description |
|---|---|---|
| `WEBAPI_TRADE_PLATFORM` | *(auto)* | Trade platform id — auto-selected when there is exactly one, required when multiple exist |
| `WEBAPI_SYMBOL` | `EURUSD` | Symbol used for the SignalR tick streaming test |
| `WEBAPI_E2E_TICK_TIMEOUT_MS` | `20000` | Deadline (ms) for the first tick to arrive |

## What is tested

### `Rest.E2E.Tests.ps1` (5 cases)

| Test | What it proves |
|---|---|
| `Get-MyWebApiTradePlatform` returns a non-empty array with string ids | OAuth token works; discovery endpoint reachable; returns `{ id: string }[]` |
| `Get-MT4ServerTime` returns a date within +/-1 day of now | Manager credential valid; MT4 call goes through; envelope `data` unwrapped; date sanity |
| `Get-MT4CfgRequestCommon` returns a non-null object | Manager-level config read succeeds |
| `Get-MT4TradesGet -All` completes; items (if any) are objects | Cursor-following pagination works end-to-end |
| `Get-MT4UserRecordGet` with a bogus login throws with an error code and activityId | The SDK throws a terminating error whose `FullyQualifiedErrorId` is `MyWebApiError,<code>` and whose message embeds `activityId=<traceId>` on a v2 error envelope |

### `SignalR.E2E.Tests.ps1` (2 cases)

| Test | What it proves |
|---|---|
| `Connect-MT4Realtime` receives `OnConnectionStatus` within 5s | WebSocket handshake succeeds; server pushes the connection-status event immediately |
| `Register-MT4Realtime` (Ticks) receives a tick with symbol/bid/ask | Subscribe + streamed payload delivers a tick shaped `{ symbol, bid, ask }` |

## Notes

- **Manager rights required**: `Get-MT4ServerTime`, `Get-MT4CfgRequestCommon`, and `Get-MT4TradesGet` need a credential with MANAGER permissions on the connected platform. A user-only credential returns HTTP 403 and those tests will fail.
- **Active price feed required** for the tick streaming test. On a closed market or a platform with no live prices the test will time out. Extend `WEBAPI_E2E_TICK_TIMEOUT_MS` if the feed is slow.
- The `.env` file is gitignored. Never commit credentials.
- **Skip-clean guarantee**: every `It` in both files lives inside a `Describe -Skip:(-not $script:E2EEnabled)` block, and the gate is computed as a top-level statement in `_Setup.ps1` (evaluated during Pester's Discovery phase, before any `BeforeAll` runs). Running `Invoke-Pester ./e2e` without `WEBAPI_E2E=1` always produces `Skipped`, never `Failed`, and always exits `0`.

## Run

```powershell
Invoke-Pester ./e2e -Output Detailed
```
