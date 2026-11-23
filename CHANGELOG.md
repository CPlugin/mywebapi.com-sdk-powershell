# Changelog

All notable changes to the `MyWebApi` PowerShell module. The module follows [semver](https://semver.org/); while it is at `0.x`, a minor release may contain breaking changes.

## 0.4.0

Regenerated from the WebAPI v2 specification of 23.11.2026 (223 paths; 224 generated cmdlets, 237 exported functions). The MT5 surface reaches the full administrative set, MT5 names match v1 again, and the hub connection-status event now carries the platform name.

### Added

- MT5 client records: `Get-MT5ClientRequest`, `Invoke-MT5ClientAdd`, `Invoke-MT5ClientDelete` and `Invoke-MT5ClientUserAdd`.
- MT5 deals: `Get-MT5DealRequest`, `Get-MT5DealRequestByGroup`, `Get-MT5DealRequestByGroupSymbol`, `Get-MT5DealRequestByLogins`, `Get-MT5DealRequestByTicket`, `Get-MT5DealRequestByTickets`, `Invoke-MT5DealRequestByTickets`, `Invoke-MT5DealUpdate` and `Invoke-MT5DealDeleteBatch`.
- MT5 orders and positions: `Get-MT5OrderGet`, `Get-MT5OrderGetByGroup`, `Get-MT5OrderGetByLogins`, `Get-MT5OrderGetBySymbol`, `Get-MT5OrderGetByTickets`, `Get-MT5OrderRequestByGroup`, `Get-MT5OrderRequestByGroupSymbol`, `Invoke-MT5OrderRequestByTickets`, `Invoke-MT5OrderDeleteBatch`; the same reads and batch deletes for positions (`Get-MT5PositionGet*`, `Invoke-MT5PositionDeleteBatch`).
- MT5 history, users, symbol arrays and dealer operations: `Get-MT5HistoryRequest`, `Get-MT5HistoryRequestByGroup`, `Invoke-MT5HistoryRequestByTickets`, `Get-MT5UserAccountGet`, `Get-MT5UserAccountRequest`, `Get-MT5UserGetByGroup`, `Get-MT5UserGetByLogins`, `Get-MT5UserRequest`, `Invoke-MT5UserAdd`, `Invoke-MT5UserDelete`, `Invoke-MT5UserUpdate`, `Invoke-MT5UserPasswordCheck`, `Invoke-MT5UserPasswordChange`, `Get-MT5SymbolRequestArray`, `Invoke-MT5SymbolUpdate`, `Invoke-MT5DealerBalance`, `Invoke-MT5DealerBalanceRaw` and `Invoke-MT5DealerSend`.
- MT4: `Get-MT4ManagerCommonEx`, `Get-MT4CfgRequestGroup`, `Get-MT4CfgRequestSymbolGroup`, `Get-MT4SymbolsGetAll`, `Get-MT4SymbolsGetAllBySymbol`, `Get-MT4UsersGet` and `Invoke-MT4CfgUpdateGroup`.

### Changed

- MT5 names are those of v1 again: `Get-MT5TimeServer` (was `Get-MT5ServerTime`), `Get-MT5GroupRequest` for the live read beside the cached `Get-MT5GroupGet`, `Get-MT5OrderGetByGroup` (was `Get-MT5OrderByGroup`), `Get-MT5DealRequestByGroup` (was `Get-MT5DealByGroup`) and `Get-MT5PositionRequestByGroup` (was `Get-MT5PositionByGroup`).
- `Invoke-MT4UserRecordUpdate` updates the account named in the body; the `{login}` in the route is gone, and the body uses the `MT4UserUpdate` schema. `Invoke-MT4CfgUpdateGroup` uses `MT4GroupUpdate`.
- Update bodies carry only the fields you send: `UserUpdate`, `SymbolUpdate`, `CfgUpdateGroup`, `CfgUpdateCommon` and `UserRecordUpdate` accept a partial object, and an empty body is refused by the server.
- `Connect-MT4Realtime` and `Connect-MT5Realtime` register the hub-specific status event: payloads now arrive as `OnMT4ConnectionStatus` and `OnMT5ConnectionStatus`, there is no shared `OnConnectionStatus`.

### Removed

- Duplicate cmdlets that the specification no longer lists: `Get-MT4SymbolsGroupsGet`, `Invoke-MT4GroupRecordUpdate`, and the GET twins of mutating operations. The `-Login` path parameter of `Invoke-MT4UserRecordUpdate` is gone as well; the account is named in the body.

### Notes

- The new and renamed cmdlets need a server that serves the 23.11.2026 v2 contract; an older server answers the removed routes with 404 and does not know the new operations.
- Authorization is checked by effect: `Invoke-MT4AdmBalanceFix`, `Invoke-MT4SymbolAdd`, `Invoke-MT4SymbolHide` and `Invoke-MT4SymbolsRefresh` need Update rather than Request rights, `Invoke-MT4TradeTransaction` needs Update rather than Create, and `Get-MT5DealRequestByTicket` needs the order right.

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
