# Changelog

All notable changes to the `MyWebApi` PowerShell module. The module follows [semver](https://semver.org/); while it is at `0.x`, a minor release may contain breaking changes.

## 0.3.2

Batched ticks on the MT4 and MT5 v2 hubs. Needs a server that pushes the `OnTicksBatch` event on `/hubs/mt4/v2` and `/hubs/mt5/v2`; an older server refuses the batch subscription instead.

### Added

- `Register-MT5Realtime -Category TicksBatch -Symbol ...` — subscribes a symbol to batched ticks. `-IntervalMs` (20..60000, default 200) is the longest a tick waits for its batch, `-MaxBatchSize` (1..10000, default 200) the maximum ticks in one payload; `-TimeoutSeconds` bounds the wait for the hub to confirm each symbol.
- `Register-MT4Realtime -Category TicksBatch -Symbol ...` — the same batched subscription on the MT4 v2 hub, with the same `-IntervalMs` and `-MaxBatchSize`.
- `Unregister-MT4Realtime -Symbol ...` — removes a per-tick (`-Category Ticks`, default) or batched (`-Category TicksBatch`) subscription of a symbol without closing the connection; the MT4 layer had no such cmdlet before.

### Changed

- `Unregister-MT5Realtime` takes `-Category Ticks` (default) or `TicksBatch`, so the batched subscription of a symbol is removed with `UnsubscribeFromTicksBatch`.
- `Connect-MT4Realtime` and `Connect-MT5Realtime` register the `OnTicksBatch` handler once per connection.
- Batched ticks arrive from `Receive-MT4Realtime` and `Receive-MT5Realtime` as `OnTicksBatch` payloads (`symbol`, `ticks`; each tick with `symbol`, `bid`, `ask`, `last`, `lastTime`, `volumeExt`, `flags`). A batched symbol receives no per-tick `OnTick`; its per-tick and batched subscriptions are separate, so both can exist for one symbol.

## 0.3.1

MT5 v2 market data and streaming ticks. Needs a server that serves `GET /api/v2/MT5/{tradePlatform}/ChartRequest/{symbol}` and `.../TicksHistory/{symbol}` and pushes the `OnTick` event on `/hubs/mt5/v2`; an older server simply has no data behind these cmdlets.

### Added

- `Get-MT5ChartRequest` — chart bars of one symbol: `-Period` (`M1`, `M5`, `M15`, `M30`, `H1`, `H4`, `D1`), `-From`/`-To` window and `-Limit` (0 = every bar). The answer carries `bars`, `total` and `truncated`.
- `Get-MT5TicksHistory` — tick history of one symbol over the same window; the answer carries `ticks`, `total` and `truncated`.
- `Register-MT5Realtime -Category Ticks -Symbol ...` — per-symbol tick subscription on the MT5 v2 hub, mirroring the MT4 layer; `-TimeoutSeconds` bounds the wait for the hub to confirm each symbol.
- `Unregister-MT5Realtime -Symbol ...` — removes a tick subscription without closing the connection.
- MT5 ticks arrive from `Receive-MT5Realtime` as `OnTick` payloads (`symbol`, `bid`, `ask`, `last`, `lastTime`, `volumeExt`, `flags`); `Connect-MT5Realtime` registers that handler once per connection.

### Changed

- Cmdlets regenerated from the current server spec. The spec keeps the new document merged with the 13 MT4 x86 sidecar operations that the x64 build's document does not list (plugins, mails and news, batch snapshots and sync reads, `ExternalCommandBinary`), so no existing command was lost — 174 operations in total.
- `Invoke-MT4NotificationsSend` documents the operation summary from the spec ("Send push notification") and the body it takes.

### Unchanged on purpose

- `Register-MT5Realtime -Category MarginCall` and the rest of the MT5 surface keep their behaviour.
