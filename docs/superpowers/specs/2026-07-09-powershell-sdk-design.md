# PowerShell SDK — Design Spec

Date: 2026-07-09
Status: Approved (design), pending implementation plan
Owner: BobBoba

## Goal

Ship a PowerShell SDK for the WebAPI **v2** surface — the fifth and final language SDK (after TypeScript, Python, .NET, and the earlier JavaScript work). It exposes the full REST v2 API as idiomatic cmdlets plus a SignalR realtime client, distributed as a public GitHub repository and published to the PowerShell Gallery.

This SDK follows the established standalone-repo pattern: extracted into its own git repository, hosted at `CPlugin/mywebapi.com-sdk-powershell` on GitHub (public), local working copy at `/code/web/cplugin-webapi-sdk-powershell`.

## Decisions (locked)

| Topic | Decision |
|-------|----------|
| Target runtime | PowerShell 7.4+ only (cross-platform, .NET 8/9). No Windows PowerShell 5.1. |
| Module name | `MyWebApi` (aligns with .NET `MyWebApi.Sdk`) |
| Distribution | Public GitHub repo + PowerShell Gallery (tag-gated publish) |
| Scope | REST v2 (all 172 operations) + SignalR realtime |
| Generation approach | Custom generator emits idiomatic **script** cmdlets from `spec/v2.json`; SignalR hand-written over the bundled `Microsoft.AspNetCore.SignalR.Client` assembly |
| Cmdlet naming | Verb from HTTP method; noun = `MT4`/`MT5` + full API action segment **verbatim** |
| Case | `MT4` / `MT5` always uppercase (cmdlet nouns, identifiers, docs) |

## Why this approach (Approach A)

Three approaches were considered:

- **A — Custom generator → idiomatic script module + hand-written SignalR (chosen).** Pure-script `.psm1`/`.ps1`, no compile step, fully readable in a public repo, native PowerShell Gallery publish, cross-platform on PS 7+. Takes a .NET dependency only where genuinely required (SignalR, which has no native PowerShell client). Matches the "generate REST, hand-write realtime" pattern used by every other SDK.
- **B — AutoRest PowerShell generator (binary/C# module).** Rejected: produces an opaque compiled module needing a full build toolchain, essentially re-skinning the .NET SDK we already have; SignalR still not generated; harder to review publicly.
- **C — Thin script wrapper over the .NET SDK (`MyWebApi.Sdk`).** Rejected: hard version coupling, must bundle the entire .NET dependency graph, marshals .NET objects instead of native PowerShell objects, and every .NET SDK release forces a re-bundle.

## API surface (from `spec/v2.json`)

- 172 operations total. `operationId` is **empty** on every operation, so the generator keys off the **trailing path segment** (the API action name, e.g. `UserRecordGet`, `TradesGet`, `CfgRequestCommon`).
- 7 cached/live pairs exist — `UserRecord`, `Trades`, `TradeRecord`, `Online`, `Groups`, `MarginLevel`, `NewsBody` — each with a cached `…Get` variant and a live `…Request` variant. These are semantically distinct and both must be exposed; the `Get`/`Request` suffix is a disambiguator that must be preserved in the name.
- Verb distribution under the chosen scheme: 88 `Get-`, 78 `Invoke-`, 6 `Update-`.

## Cmdlet naming rule

- Verb derived purely from the HTTP method: `GET` → `Get`, `POST` → `Invoke`, `PATCH` → `Update`, `PUT` → `Set`, `DELETE` → `Remove`.
- Noun = `MT4` or `MT5` (uppercase) + the trailing API action segment, verbatim (case preserved).
- Deriving the verb from the HTTP method (not from the action name) avoids a per-action override table for the 99 actions that carry no trailing verb token, and keeps names 1:1 with the API.

Examples:

```
GET   CfgRequestCommon    -> Get-MT4CfgRequestCommon
POST  CfgUpdateCommon     -> Invoke-MT4CfgUpdateCommon
GET   UserRecordGet       -> Get-MT4UserRecordGet       (cached)
GET   UserRecordRequest   -> Get-MT4UserRecordRequest   (live)
POST  UserPasswordCheck   -> Invoke-MT4UserPasswordCheck
POST  NotificationsSend   -> Invoke-MT4NotificationsSend
POST  ChartDelete         -> Invoke-MT4ChartDelete
PATCH UserRecord (MT5)    -> Update-MT5UserRecord
```

All verbs are approved PowerShell verbs, so `Import-Module MyWebApi` emits no "unapproved verbs" warning and `PSScriptAnalyzer`'s `PSUseApprovedVerbs` passes.

## Repository layout

```
cplugin-webapi-sdk-powershell/            # GitHub: CPlugin/mywebapi.com-sdk-powershell
├── src/MyWebApi/
│   ├── MyWebApi.psd1          # manifest: version, PS 7.4+, explicit FunctionsToExport, RootModule
│   ├── MyWebApi.psm1          # loader: dot-sources Public/ + Private/, Add-Type sink, loads lib/
│   ├── Public/
│   │   ├── Connect-MyWebApi.ps1        # OAuth2 bootstrap, stores session context
│   │   ├── Disconnect-MyWebApi.ps1
│   │   ├── MT4/               # generated REST cmdlets (Get-MT4…, Invoke-MT4…)
│   │   ├── MT5/               # generated REST cmdlets (Get-MT5…, Update-MT5…)
│   │   └── Realtime/          # hand-written SignalR cmdlets
│   ├── Private/               # Invoke-MyWebApiRequest, token cache, paging helper
│   ├── Classes/               # PowerShell classes: session context, options, realtime client
│   └── lib/                   # bundled managed DLLs (SignalR client + deps); restored at build
├── spec/v2.json              # fetched OpenAPI v2 spec (source of truth for REST)
├── build/GenerateCmdlets/    # the code generator (file-based C# app)
├── scripts/                  # fetch-spec.sh · restore-lib.sh · generate.sh · build.ps1
├── tests/                    # Pester unit tests (mocked HTTP)
├── e2e/                      # gated integration tests (staging, REST only)
├── examples/
├── README.md  ·  PUBLISHING.md  ·  LICENSE
└── .github/workflows/        # ci.yml · publish.yml
```

Generated code (`Public/MT4`, `Public/MT5`) and hand-written code (`Public/Realtime`, `Connect-*`, `Private/`, `Classes/`) are physically separated so regenerating REST never clobbers bespoke code.

## REST code generation

The generator (`build/GenerateCmdlets/`, a file-based C# app mirroring the .NET SDK's `GenerateEndpoints`):

1. Parses `spec/v2.json`. For each path+method emits one `.ps1` into `Public/MT4/` or `Public/MT5/`:
   - Name = `<HttpVerb>-<Platform><ActionVerbatim>`.
   - Parameters: path params (`{tradePlatform}`, `{login}`, `{ticket}`, …) → mandatory typed params; query params → optional typed params; request body → a shaped param. Comment-based help is lifted from the OpenAPI `summary`/`description` for the cmdlet and each parameter.
   - Mutating cmdlets (POST/PATCH/DELETE) get `[CmdletBinding(SupportsShouldProcess)]` so `-WhatIf`/`-Confirm` work. Operations under the spec's `… (destructive)` tags (`SrvRestart`, `BackupRestore*`, `Cfg*Delete`) get `ConfirmImpact = 'High'` and prompt before firing unless `-Force`.
   - Body only marshals arguments and calls the private `Invoke-MyWebApiRequest`. No business logic in generated files.
2. Writes the explicit `FunctionsToExport` array into the manifest (never `'*'` — explicit export keeps module load fast and `Get-Command` clean).
3. No silent drops: any operation the generator cannot map emits a build warning that fails CI.

## Request pipeline

`Private/Invoke-MyWebApiRequest.ps1` is the single choke point every REST cmdlet flows through:

- Resolves base URL + bearer token from session context; refreshes the token if near expiry.
- Builds the URL, serializes query/body, calls `Invoke-RestMethod`.
- Unwraps the v2 envelope: returns `.data` as native `PSCustomObject`s (pipeline-friendly), surfaces `.meta` (cursor paging), and on `.error` throws a terminating error record carrying the `WebApiErrorCode`, message, and `ActivityId` (for support).
- Paging: list cmdlets expose `-Limit`/`-Cursor` plus an `-All` switch that follows `meta.hasMore`/cursor until exhausted (matching the Python/JS SDK behavior).
- Common cross-cutting params on applicable cmdlets: `-CacheId`/`-CacheTimeout` (the API's idempotent cache) and `-IdempotencyKey` (header).

## Authentication and session

- `Connect-MyWebApi` — params: `-BaseUrl`, `-ClientId`, `-ClientSecret` (as `[SecureString]`), optional `-Authority`/`-Scope`, optional `-DefaultTradePlatform`, and an alternative `-AccessToken` for CI / short-lived use. Runs the OAuth2 client-credentials flow against IdentityServer and caches the token + expiry + base URL in a module-scoped context (`$script:MyWebApiContext`).
- Token lifecycle: auto-refresh before expiry inside the request pipeline. The client secret and access token are never logged and are handled only as `SecureString` / in-memory values.
- `-TradePlatform`: every route carries `{tradePlatform}` (which broker instance). It is a non-mandatory cmdlet param; when omitted it falls back to the session's `-DefaultTradePlatform`, and the request pipeline throws a clear terminating error if neither is set. This keeps interactive use terse while still requiring the value.
- `Disconnect-MyWebApi` — clears the context and zeroes the token.

## SignalR realtime

Hub endpoints: `/hubs/mt4/v2` and `/hubs/mt5/v2` (the v2 SDK hub paths). Token passed via the `signalr_token` query parameter. Payload categories mirror the .NET SDK: `Tick`, `TradeUpdate`, `UserUpdate`, `SymbolUpdate`, `MarginCall`, `ConnectionStatus`. Hub server methods follow the `SubscribeToTicks` / `UnsubscribeFromTicks` pattern per category.

Design constraint: SignalR `.On` handlers fire on arbitrary threads, but a PowerShell `ScriptBlock` cast to a delegate needs a runspace on its thread — invoking one from a SignalR callback throws "no Runspace available". The design sidesteps this entirely:

- `lib/` bundles `Microsoft.AspNetCore.SignalR.Client` plus its managed dependency graph (restored at build, bundled at publish).
- A small inline C# sink (`Add-Type` at module import) — `RealtimeSink` — owns the `HubConnection` and a thread-safe `BlockingCollection<object>`. Its `.On(...)` handlers are compiled delegates (no runspace needed) that deserialize each payload's raw JSON and enqueue it.
- Cmdlets (`Public/Realtime/`, hand-written):
  - `Connect-MT4Realtime` / `Connect-MT5Realtime` — build the hub URL from session context, append `signalr_token`, `WithAutomaticReconnect()`, start the connection, and return a connection object wrapping the sink.
  - `Subscribe-MT4Realtime -Category Ticks,Trades,MarginCall,… [-Symbol …] [-Login …]` — invokes the matching hub method.
  - `Receive-MT4Realtime -Connection $c [-TimeoutSeconds N]` — streams dequeued payloads to the pipeline as native `PSCustomObject`s. Idiomatic usage: `Receive-MT4Realtime $c | ForEach-Object { … }`.
  - `Disconnect-MT4Realtime` — stops and disposes the connection.
- Payloads surface as `PSCustomObject` (raw JSON → `ConvertFrom-Json`), so there are no compiled payload types to maintain.

Deferred (explicitly not built in v1): scriptblock callbacks (`Register-…Handler`) would need a background runspace draining the queue. The streaming `Receive-` model covers v1 cleanly.

## Tooling, tests, CI/CD

- `scripts/`:
  - `fetch-spec.sh` — pull `v2.json` from a running API (as the other SDKs do).
  - `restore-lib.sh` — a tiny csproj → restore `Microsoft.AspNetCore.SignalR.Client` (+deps) into `src/MyWebApi/lib`. Not committed as binaries; CI restores, publish bundles.
  - `generate.sh` — run the C# generator over the spec into `Public/MT4` + `Public/MT5`.
  - `build.ps1` — assemble the module, `Test-ModuleManifest`, `Invoke-ScriptAnalyzer`.
- Tests (Pester) in `tests/`: `Mock Invoke-RestMethod`, assert URL/verb/query/body, envelope unwrap, cursor paging (`-All`), error → terminating-record mapping, and the sink queue logic. Gated `e2e/` hits staging (REST only, like the Python SDK; skipped without creds).
- CI (`ci.yml`): PS7 → restore lib → `PSScriptAnalyzer` + Pester on push/PR.
- `publish.yml`: tag-gated → `Publish-PSResource` to the PowerShell Gallery using an API key from a gated `psgallery` GitHub environment secret. (PS Gallery has no NuGet-style trusted publishing, so it uses an API key.)
- Docs: `README.md` (quickstart + trademark disclaimer), `PUBLISHING.md`, MIT `LICENSE`. Repo name, module name, description, and Gallery tags stay neutral; platform terms (`MT4`/`MT5`) appear only in cmdlet nouns and internal identifiers, matching the other SDKs.

## Out of scope (v1)

- Windows PowerShell 5.1 support.
- Scriptblock realtime callbacks (`Register-…Handler`).
- Compiled/binary module output.
- Typed payload/model classes for REST responses (responses surface as `PSCustomObject`); `Format.ps1xml` display views may be added later.
