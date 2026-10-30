# Changelog

All notable changes to the `MyWebApi` PowerShell module. The module follows [semver](https://semver.org/); while it is at `0.x`, a minor release may contain breaking changes.

## 0.3.4

MT5 market history over REST, real-time ticks on the MT5 v2 hub and batched ticks on both v2 hubs. Additive: existing cmdlets and subscriptions are unchanged.

### Added

- `Get-MT5ChartRequest` — chart bars of one symbol from `GET /api/v2/MT5/{tradePlatform}/ChartRequest/{symbol}`: `-Period` (`M1`, `M5`, `M15`, `M30`, `H1`, `H4` or `D1`, default `M1`), the `-From`/`-To` window and `-Limit` (0 = every bar). The answer carries `bars` ordered by time ascending, `total` and `truncated`. Bars coarser than a minute are aggregated by the server from its minute history on the boundaries of its trading time, so a day starts at 00:00 of the server clock. Times are the trade server's trading times, not UTC.
- `Get-MT5TicksHistory` — historical ticks of one symbol from `GET /api/v2/MT5/{tradePlatform}/TicksHistory/{symbol}` over the same window; the answer carries `ticks` ordered by time ascending with `total` and `truncated`. Prices come as the platform holds them, without rescaling; `flags` names the set tick-kind bits, as in the streaming events.
- `Register-MT5Realtime -Category Ticks -Symbol ...` — per-symbol tick subscription on the MT5 v2 hub, mirroring the MT4 layer. `Connect-MT5Realtime` registers the `OnTick` handler once per connection, and ticks arrive from `Receive-MT5Realtime` as `OnTick` payloads (`symbol`, `bid`, `ask`, `last`, `lastTime`, `volumeExt`, `flags`).
- `Unregister-MT5Realtime -Symbol ...` — removes a per-tick (`-Category Ticks`, default) or batched (`-Category TicksBatch`) subscription of a symbol without closing the connection.
- `Register-MT4Realtime -Category TicksBatch -Symbol ...` and `Register-MT5Realtime -Category TicksBatch -Symbol ...` — batched tick subscriptions on the v2 hubs. `-IntervalMs` (20..60000, default 200) is the longest a tick waits for its batch, `-MaxBatchSize` (1..10000, default 200) the maximum ticks in one payload, `-TimeoutSeconds` bounds the wait for the hub to confirm each symbol.
- `Unregister-MT4Realtime -Symbol ...` — removes a per-tick or batched subscription on the MT4 v2 hub; the MT4 layer had no such cmdlet before.
- Batched ticks arrive from `Receive-MT4Realtime` and `Receive-MT5Realtime` as `OnTicksBatch` payloads (`symbol`, `ticks`; each tick with `symbol`, `bid`, `ask`, `last`, `lastTime`, `volumeExt`, `flags`). A batched symbol receives no per-tick `OnTick`; its per-tick and batched subscriptions are separate, so both can exist for one symbol.

### Changed

- `Connect-MT4Realtime` and `Connect-MT5Realtime` register the `OnTicksBatch` handler once per connection; `Connect-MT5Realtime` also registers `OnTick`.
- Cmdlets regenerated from the current server specification — 174 operations, one cmdlet each. The 13 MT4 x86 sidecar operations, which the current x64 specification does not list, are kept in `spec/v2.json` with their schemas (plugins, mails and news, batch snapshots and sync reads, `ExternalCommandBinary`), so no existing cmdlet was lost.
- The rejection messages of the real-time tick subscriptions name the symbol that did not confirm in time.

### Notes

- The new cmdlets need a server that serves both MT5 history operations and pushes `OnTick` on `/hubs/mt5/v2`; the batched subscriptions need a server that pushes `OnTicksBatch` on `/hubs/mt4/v2` and `/hubs/mt5/v2`. An older server simply has no data behind the history cmdlets and refuses a batch subscription.

## 0.3.3

Regenerated from the WebAPI v2 specification of 05.10.2026; no change to the cmdlets.

### Changed

- The operation and schema texts, which become the cmdlet help, no longer name the server's internal library; they speak about the trade server itself.

## 0.3.1

Regenerated from the WebAPI v2 specification of 03.10.2026; no change to the cmdlets.

### Changed

- `Invoke-MT4TradeTransaction` and `Invoke-MT4TradeCheckStops` document the values the server accepts for `tradeTransactionType`, `tradeCommand` and `tradeRequestFlags`, and `Invoke-MT4UsersGroupOp` for `command`; the old help listed names such as `ModifyTrade` and `BalanceAdd` that the server does not know.
- An unknown value in those fields is refused by the server with error code `Validation` (`$_.TargetObject.Code`) instead of silently becoming the default. The behaviour belongs to the server, so it applies to every module version.

## 0.3.0

Request timeouts.

### Added

- `-RequestTimeout` (seconds, 1–300) on every REST cmdlet, sent as the `X-Request-Timeout` header, and `Connect-MyWebApi -RequestTimeout` as the session default.
- `Timeout`, `OutcomeUnknown` and `Busy` errors carry the `X-Request-Outcome` value, the `Retryable` flag and the guidance on `TargetObject`, `Exception.Data` and `ErrorDetails.RecommendedAction`; a client-side HTTP deadline is reported as `MyWebApiHttpTimeout`.

### Changed

- The HTTP deadline follows the server timeout plus 30 s, so the server's answer arrives instead of an ambiguous client-side abort.
- Busy GETs are retried within `-MaxGetRetries`; writes are never retried.
