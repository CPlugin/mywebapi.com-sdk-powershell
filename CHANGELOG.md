# Changelog

All notable changes to the `MyWebApi` PowerShell module. The module follows [semver](https://semver.org/); while it is at `0.x`, a minor release may contain breaking changes.

## [0.6.1]

### Fixed

- Release re-cut: `MyWebApi.Sdk` 0.6.0 did not reach nuget.org while `MyWebApi.Sdk.Models` 0.6.0 did, so the four SDKs move to 0.6.1 together. The API surface is identical to 0.6.0.

## 0.6.0

Regenerated from the refreshed WebAPI v2 specification of 24.11.2026 (453 paths, 456 generated cmdlets, 469 exported functions — the same surface as 0.5.1, no cmdlet added, removed or renamed).

### Changed

- `MT5ConSubscription` carries `priceCost` — the real cost of the subscription, the amount the client is actually charged — next to `price` and `priceCurrency`. Returned by `Get-MT5SubscriptionCfgGet` and the other configuration reads, and accepted on input.
- `MT5SubscriptionHistory` carries `time` — the time of the subscription action, in seconds since 1970-01-01. Returned by `Get-MT5SubscriptionHistoryRequest` and the other history reads, and accepted on input.
- The sandbox server (`https://pre.mywebapi.com`) is listed in the specification before production, and the tag and `TickStream` descriptions now point to the published history page instead of a repository file.

### Notes

- A request body stays a free-form hashtable or `[pscustomobject]`; the new fields need no module change, only the regenerated help text reflects the specification.

## 0.5.1

Regenerated from the refreshed WebAPI v2 specification of 23.11.2026 (453 paths, 456 generated cmdlets, 469 exported functions — the same surface as 0.5.0, no cmdlet added, removed or renamed).

### Changed

- Subscription models in the specification are typed enumerations instead of integer codes: `MT5ConSubscription` (`type`, `controlMode`, `periodMode`, `periodFreeMode`, `flags`) and `MT5ConSubscriptionSymbol` (`level`, `tickHistory`), `MT5Subscription` (`status`, `flags`) and `MT5SubscriptionHistory` (`action`). Each is sent and returned by name — for example `periodMode = 'Monthly'`, `level = 'RealtimeLevel2'`, `status = 'Active'`, `flags = 'FreePeriod'` — and the numeric value is still accepted on input. The flag values (`MT5ConSubscriptionFlags`, `MT5SubscriptionFlags`) are written as the names of the set bits joined by `, `, `None` when none is set.
- `MT5MarketTickStat` carries the price Greeks: `priceGreeksDelta`, `priceGreeksTheta`, `priceGreeksGamma`, `priceGreeksVega`, `priceGreeksRho`, `priceGreeksOmega` and `priceSensitivity`. The cmdlets pass the response through unchanged, so `Get-MT5TickStat` shows them without a code change.
- News time is the wall-clock time of the trade server in both directions: `MT5News.time` and `MT5NewsSendRequest.time` are returned and expected without a zone offset, in the server's time zone, and the previous "in UTC" wording is gone.
- Per-operation default `-RequestTimeout` follows the refreshed specification: reads now default to 30 s (was 10 s, "history or report" category), trade operations to 5 s (was 15 s).

### Notes

- A request body stays a free-form hashtable or `[pscustomobject]`; the new fields and enum names need no module change, only the regenerated help text reflects the specification.

## 0.5.0

Regenerated from the extended WebAPI v2 specification of 23.11.2026 (440 paths on the x64 deployment, plus the 13 MT4 x86 sidecar paths kept in the vendored spec — 453 paths, 456 generated cmdlets, 469 exported functions). Every cmdlet of 0.4.0 keeps its name and parameters; the release is additive.

### Added

- MT5 users and client records: `Get-MT5UserCertGet`, `Invoke-MT5UserCertConfirm`, `Invoke-MT5UserCertUpdate`, `Invoke-MT5UserCertDelete`, `Get-MT5UserExternalGet`, `Get-MT5UserExternalRequest`, `Invoke-MT5UserExternalSync`, `Get-MT5UserGroup`, `Get-MT5UserLogins`, `Get-MT5UserRequestArray`, `Get-MT5UserRequestByLogins`, `Get-MT5UserAccountGetByGroup`, `Get-MT5UserAccountGetByLogins`, `Get-MT5UserAccountRequestArray`, `Get-MT5UserAccountRequestByLogins`, `Invoke-MT5UserBalanceCheck`, `Invoke-MT5UserBalanceCheckBatch`, `Invoke-MT5UserUpdateBatch`, `Invoke-MT5UserUpdateBatchArray`, `Invoke-MT5UserDeleteBatch`; clients: `Get-MT5ClientRequestByGroup`, `Get-MT5ClientRequestHistory`, `Get-MT5ClientUserRequest`, `Invoke-MT5ClientUpdate`, `Invoke-MT5ClientAddBatch`, `Invoke-MT5ClientAddBatchArray`, `Invoke-MT5ClientUpdateBatch`, `Invoke-MT5ClientUpdateBatchArray`, `Invoke-MT5ClientDeleteBatch`, `Invoke-MT5ClientUserAddBatch`, `Invoke-MT5ClientUserDelete`, `Invoke-MT5ClientUserDeleteBatch`.
- MT5 CRM documents: comments (`Get-MT5CommentRequest`, `...ByClient`, `...ByDocument`, `Invoke-MT5CommentAdd/Update/Delete` and batch variants), documents (`Get-MT5DocumentRequest`, `...ByClient`, `...History`, `Invoke-MT5DocumentAdd/Update/Delete` and batch variants), attachments (`Get-MT5AttachmentRequest`, `Invoke-MT5AttachmentAdd`, `Invoke-MT5AttachmentAddBatch`, `Invoke-MT5AttachmentAddBatchArray`).
- MT5 subscriptions: configurations (`Get-MT5SubscriptionCfgGet`, `...ByID`, `...Request`, `...RequestByID`), live subscriptions (`Get-MT5SubscriptionRequest`, `...ByGroup`, `...ByID`, `...ByIDs`, `...ByLogins`, `Invoke-MT5SubscriptionJoin`, `...JoinBatch`, `Invoke-MT5SubscriptionUpdate`, `...UpdateBatch`, `...UpdateBatchArray`, `Invoke-MT5SubscriptionCancel`, `...CancelBatch`, `Invoke-MT5SubscriptionDelete`, `...DeleteBatch`) and history (`Get-MT5SubscriptionHistoryRequest`, `...ByGroup`, `...ByID`, `...ByIDs`, `...ByLogins`, `Invoke-MT5SubscriptionHistoryUpdate`, `...UpdateBatch`, `...UpdateBatchArray`, `Invoke-MT5SubscriptionHistoryDelete`, `...DeleteBatch`).
- MT5 trading and market data: `Invoke-MT5OrderAdd`, `...AddBatch`, `...AddBatchArray`, `Invoke-MT5OrderUpdate`, `...UpdateBatch`, `...UpdateBatchArray`, `Invoke-MT5OrderCancel`, `...CancelBatch`, `Invoke-MT5OrderDelete`, `Get-MT5OrderRequest`, `...ByLogins`, `...ByLoginsSymbol`, `Get-MT5OrderGetOpen`, `Get-MT5OrderRequestOpen`, `Invoke-MT5DealAdd`, `...AddBatch`, `...AddBatchArray`, `Invoke-MT5DealPerform`, `...PerformBatch`, `...PerformBatchArray`, `Invoke-MT5DealDelete`, `Invoke-MT5DealUpdateBatch`, `...UpdateBatchArray`, `Get-MT5DealRequestByLoginsSymbol`, `Get-MT5DealRequestPage`, `Get-MT5HistoryRequestByLogins`, `...ByLoginsSymbol`, `...ByGroupSymbol`, `Get-MT5HistoryRequestPage`, `Invoke-MT5PositionSplit`, `Invoke-MT5PositionUpdate`, `...UpdateBatch`, `...UpdateBatchArray`, `Invoke-MT5PositionDeleteByTicket`, `Invoke-MT5PositionRequestByTickets`, `Invoke-MT5TradeMarginCheck`, `...Ext`, `Invoke-MT5TradeProfit`, `...Ext`, `Invoke-MT5TradeRateBuy`, `...Sell`, `Invoke-MT5TradeAccountSet`, `Get-MT5BookGet`, `Get-MT5TickLast`, `...Raw`, `Get-MT5TickStat`, `Get-MT5TickHistoryRequestRaw`, `Invoke-MT5TickAdd`, `...Batch`, `...Stat`, `Invoke-MT5TickHistoryAdd`, `...Replace`.
- MT5 dealer workstation: `Invoke-MT5DealerGet`, `DealerStart`, `DealerStop`, `DealerLock`, `DealerAnswer`, `Invoke-MT5SelectedAdd`, `...AddAll`, `...AddBatch`, `...Delete`, `...DeleteAll`, `...DeleteBatch`, `...Next`, `...Shift`, `Get-MT5RequestGet`, `Get-MT5RequestGetAll`.
- MT5 server operation: `Get-MT5GeoResolve`, `...Batch`, `Get-MT5SettingGet`, `Invoke-MT5SettingSet`, `...Delete`, `Invoke-MT5NetworkRescan`, `Get-MT5NetworkAddress`, `...BytesRead`, `...BytesSent`, `...Server`, `Invoke-MT5LoggerFlush`, `...Out`, `...OutString`, `Get-MT5LoggerServerRequest`, `Invoke-MT5ProxySet`, `Invoke-MT5CustomCommand`, `Invoke-MT5LicenseCheck`, `Invoke-MT5PasswordChange`, `Get-MT5PluginGet`, `Invoke-MT5PluginUpdate`, `Invoke-MT5GroupUpdate`, `...Batch`, `Get-MT5SymbolRequest`, `Get-MT5SymbolExist`, `Invoke-MT5SymbolUpdateBatch`, `Get-MT5TimeServerRequest`, `Get-MT5ExposureGet`, `...GetAll`, `Get-MT5ExposureCurrency`, `Invoke-MT5ExposureCurrency`, `Get-MT5SummaryGet`, `...GetAll`, `Get-MT5SummaryCurrency`, `Invoke-MT5SummaryCurrency`.
- MT5 communications: `Get-MT5MailRequest`, `...BodyRequest`, `Invoke-MT5MailSend`, `MailDelete`, `MailDeleteId`, `Get-MT5NewsRequest`, `...BodyRequest`, `Invoke-MT5NewsSend`, `Invoke-MT5EmailSend`, `Invoke-MT5MessengerSend`, `...VerifyPhone`, `Invoke-MT5NotificationsSend`, `Invoke-MT5OnlineDisconnect`, `...DisconnectBatch`, `Get-MT5OnlineGet`, `Get-MT5OnlineRequest`.
- MT4: summary and exposure reports (`Get-MT4SummaryGet`, `...GetAll`, `...GetByCount`, `...GetByType`, `Get-MT4SummaryCurrency`, `Get-MT4ExposureGet`, `Get-MT4ExposureValueGet`), `Invoke-MT4LogsOut`, `Invoke-MT4LogsMode`, `Invoke-MT4TradeCalcProfit`.

### Changed

- A request body that is an array is now serialized as a JSON array even when it holds one element, which the batch-array endpoints (`DealAddBatchArray`, `OrderAddBatchArray`, `AttachmentAddBatchArray`, …) require; previously the pipeline unrolled it into a single object.
- `scripts/fetch-spec.sh` merges `spec/mt4-sidecar.json` after the download, so refreshing from an x64 deployment no longer drops the 13 MT4 x86 sidecar cmdlets (the previous release kept them by hand-editing the spec).
- The release probe (`ci/fixed-artifact-consumer.ps1`) expects module 0.5.0 and at least 469 exports.

### Notes

- The new cmdlets need a server that serves the extended v2 contract (443 operations on the x64 deployment); an older server answers the added routes with 404.
- Authorization follows each operation's requirement; destructive operations keep `ConfirmImpact = 'High'`.

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
