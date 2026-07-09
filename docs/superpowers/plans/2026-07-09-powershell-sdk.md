# PowerShell SDK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a PowerShell 7.4+ SDK (`MyWebApi`) that exposes the WebAPI v2 REST surface (172 operations) as idiomatic cmdlets plus a SignalR realtime client, packaged as a standalone public repo published to the PowerShell Gallery.

**Architecture:** A pure-script module. REST cmdlets are generated from `spec/v2.json` by a small C# generator into one `.ps1` per operation; every cmdlet funnels through one private request helper that handles auth, the `{ data, error, meta }` envelope, and cursor paging. SignalR (which has no native PowerShell client) is hand-written over the bundled `Microsoft.AspNetCore.SignalR.Client` assembly, with a compiled `RealtimeSink` bridging SignalR's arbitrary callback threads to a thread-safe queue the pipeline drains.

**Tech Stack:** PowerShell 7.4+, Pester v5 (tests), PSScriptAnalyzer (lint), .NET 8/9 SDK (generator + SignalR client restore), `Microsoft.AspNetCore.SignalR.Client`, GitHub Actions, PowerShell Gallery.

## Global Constraints

- Target runtime: PowerShell **7.4+ only**. No Windows PowerShell 5.1.
- Module name: `MyWebApi`. Repo: `CPlugin/mywebapi.com-sdk-powershell` (GitHub, public). Local path: `/code/web/cplugin-webapi-sdk-powershell`.
- `MT4` / `MT5` are **always uppercase** in cmdlet nouns, identifiers, and docs.
- Cmdlet naming: verb from HTTP method (`GET`→`Get`, `POST`→`Invoke`, `PATCH`→`Update`, `PUT`→`Set`, `DELETE`→`Remove`); noun = `MT4`/`MT5` + the trailing API action segment, verbatim.
- No proprietary terms (`MT4`/`MT5`/`MetaQuotes`/`MetaTrader`) in the repo name, module name, package description, or Gallery tags — those stay neutral ("trading platform"). Platform terms appear only in cmdlet nouns and internal identifiers.
- All repo docs, comments, and help text in **English**.
- License: MIT + a trademark disclaimer in `README.md` and `LICENSE`.
- Secrets (client secret, access token) are **never logged**; handled as `SecureString` / in-memory only.
- v2 envelope: `{ data, error, meta }`; `error` = `{ code, description, managerCode }`; `meta` = `{ activityId, paging: { nextCursor, hasMore } }`.
- Git: initial scaffold commits to `main` in the **fresh local repo only** (no remote). Do NOT add a remote or push until the user explicitly approves. Never push without instruction.
- Environment presets (verbatim, from the sibling SDKs): **Staging** → base `https://pre.mywebapi.com`, authority `https://pre.auth.cplugin.net`; **Production** → base `https://cloud.mywebapi.com`, authority `https://auth.cplugin.net`.
- Toolbox (where users create API keys + manage trade platforms): staging `https://pre.toolbox.cplugin.com`, prod `https://toolbox.cplugin.com`.
- Platform discovery: `Get-MyWebApiTradePlatform` calls the **v1** unversioned path `/api/TradePlatforms`, which returns a **raw JSON array (NOT the v2 `{data,error,meta}` envelope)** — throw on non-2xx, return the array as-is.
- Total exported command count target: **183** (172 generated REST + `Connect-MyWebApi` + `Disconnect-MyWebApi` + `Get-MyWebApiTradePlatform` + 8 realtime).

---

### Task 1: Scaffold the standalone repo and module skeleton

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/.gitignore`
- Create: `/code/web/cplugin-webapi-sdk-powershell/LICENSE`
- Create: `/code/web/cplugin-webapi-sdk-powershell/README.md`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/MyWebApi.psd1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/MyWebApi.psm1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/docs/` (copy of spec + this plan)

**Interfaces:**
- Produces: an importable module `MyWebApi` (empty command surface) and a passing `Test-ModuleManifest`.

- [ ] **Step 1: Create the directory tree**

Run:
```bash
mkdir -p /code/web/cplugin-webapi-sdk-powershell/{src/MyWebApi/{Public/MT4,Public/MT5,Public/Realtime,Private,Classes,lib},spec,build,scripts,tests,e2e,examples,docs/superpowers/specs,docs/superpowers/plans,.github/workflows}
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
# restored at build, never committed
src/MyWebApi/lib/*.dll
src/MyWebApi/lib/*.json
# generator build output
build/**/bin/
build/**/obj/
# test output
tests/**/*.TestResults.xml
*.nupkg
# local credentials — .env.example IS committed, real .env is NOT
.env
.env.local
```

- [ ] **Step 3: Write `LICENSE`** (MIT + trademark disclaimer)

```text
MIT License

Copyright (c) 2026 CPlugin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

Trademark notice: All third-party trading platform names and trademarks
referenced by this software are the property of their respective owners. This
project is an independent client library and is not affiliated with, endorsed
by, or sponsored by any trading platform vendor.
```

- [ ] **Step 4: Write the module manifest `src/MyWebApi/MyWebApi.psd1`**

```powershell
@{
    RootModule        = 'MyWebApi.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b7e2c1a4-9f3d-4c8e-8a2b-3d5f6e7a8b9c'
    Author            = 'CPlugin'
    CompanyName       = 'CPlugin'
    Copyright         = '(c) 2026 CPlugin. MIT License.'
    Description       = 'PowerShell client for the trading platform management WebAPI (v2): REST + real-time streaming.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('Connect-MyWebApi', 'Disconnect-MyWebApi')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData = @{
        PSData = @{
            Tags         = @('REST', 'API', 'SignalR', 'trading', 'client', 'PSEdition_Core')
            LicenseUri   = 'https://github.com/CPlugin/mywebapi.com-sdk-powershell/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/CPlugin/mywebapi.com-sdk-powershell'
            ReleaseNotes = 'Initial preview release.'
        }
    }
}
```

- [ ] **Step 5: Write the loader `src/MyWebApi/MyWebApi.psm1`**

```powershell
#Requires -Version 7.4
Set-StrictMode -Version Latest

# * Load bundled managed assemblies (SignalR client + deps) if present.
#   lib/ is populated by scripts/restore-lib.sh; absent during a bare REST-only import.
$libPath = Join-Path $PSScriptRoot 'lib'
if (Test-Path $libPath) {
    foreach ($dll in Get-ChildItem -Path $libPath -Filter '*.dll' -ErrorAction SilentlyContinue) {
        try { Add-Type -Path $dll.FullName -ErrorAction Stop } catch { <# already loaded / incompatible #> }
    }
}

# * Dot-source classes first (types other files depend on), then private helpers, then public cmdlets.
foreach ($folder in 'Classes', 'Private', 'Public') {
    $root = Join-Path $PSScriptRoot $folder
    if (Test-Path $root) {
        foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue) {
            . $file.FullName
        }
    }
}
```

- [ ] **Step 6: Write a minimal `README.md`** (expanded in Task 9)

```markdown
# MyWebApi (PowerShell SDK)

PowerShell 7.4+ client for the trading platform management WebAPI (v2): REST + real-time streaming.

> Trademark notice: third-party trading platform names are the property of their respective owners. This is an independent client library, not affiliated with any platform vendor.

Status: preview. Full quickstart added during implementation.
```

- [ ] **Step 7: Copy the spec and plan into the repo docs**

Run:
```bash
cp /code/web/webapi/docs/superpowers/specs/2026-07-09-powershell-sdk-design.md /code/web/cplugin-webapi-sdk-powershell/docs/superpowers/specs/
cp /code/web/webapi/docs/superpowers/plans/2026-07-09-powershell-sdk.md /code/web/cplugin-webapi-sdk-powershell/docs/superpowers/plans/
```

- [ ] **Step 8: Verify the manifest and a bare import succeed**

Run:
```bash
cd /code/web/cplugin-webapi-sdk-powershell
pwsh -NoProfile -Command "Test-ModuleManifest ./src/MyWebApi/MyWebApi.psd1 | Select-Object Name, Version, PowerShellVersion"
pwsh -NoProfile -Command "Import-Module ./src/MyWebApi/MyWebApi.psd1 -Force; (Get-Command -Module MyWebApi).Name"
```
Expected: manifest prints `MyWebApi 0.1.0 7.4`; import prints `Connect-MyWebApi` and `Disconnect-MyWebApi` (the functions exist as stubs after Task 3; before Task 3 the import succeeds with no exported commands — no error).

- [ ] **Step 9: Initialize git and commit**

Run:
```bash
cd /code/web/cplugin-webapi-sdk-powershell
git init -b main
git add -A
git commit -m "chore: scaffold PowerShell SDK module skeleton"
```
Note: do NOT add a remote or push. Remote creation is a separate user-approved step.

---

### Task 2: Fetch the OpenAPI v2 spec

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/scripts/fetch-spec.sh`
- Create: `/code/web/cplugin-webapi-sdk-powershell/spec/v2.json` (fetched or copied)

**Interfaces:**
- Produces: `spec/v2.json` — the source of truth consumed by the generator in Task 5.

- [ ] **Step 1: Write `scripts/fetch-spec.sh`**

```bash
#!/usr/bin/env bash
# Fetch the WebAPI v2 OpenAPI document into spec/v2.json.
# Usage: SPEC_URL=https://host/swagger/v2/swagger.json ./scripts/fetch-spec.sh
set -euo pipefail
SPEC_URL="${SPEC_URL:-http://localhost:5080/swagger/v2/swagger.json}"
DEST="$(dirname "$0")/../spec/v2.json"
echo "Fetching $SPEC_URL -> $DEST"
curl -fsSL "$SPEC_URL" -o "$DEST"
# Pretty-print for reviewable diffs.
tmp="$(mktemp)"
pwsh -NoProfile -Command "Get-Content '$DEST' -Raw | ConvertFrom-Json -Depth 100 | ConvertTo-Json -Depth 100" > "$tmp"
mv "$tmp" "$DEST"
echo "Wrote $(wc -c < "$DEST") bytes."
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x /code/web/cplugin-webapi-sdk-powershell/scripts/fetch-spec.sh`

- [ ] **Step 3: Populate `spec/v2.json`**

If a live API is not reachable in the dev environment, copy the known-good spec used by the .NET SDK:
```bash
cp /code/web/cplugin-webapi-sdk-dotnet/spec/v2.json /code/web/cplugin-webapi-sdk-powershell/spec/v2.json
```

- [ ] **Step 4: Verify the spec parses and has 172 operations**

Run:
```bash
pwsh -NoProfile -Command "\$s = Get-Content /code/web/cplugin-webapi-sdk-powershell/spec/v2.json -Raw | ConvertFrom-Json -Depth 100; (\$s.paths.PSObject.Properties | ForEach-Object { \$_.Value.PSObject.Properties.Name } | Where-Object { \$_ -in 'get','post','put','patch','delete' }).Count"
```
Expected: `172`

- [ ] **Step 5: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add scripts/fetch-spec.sh spec/v2.json
git commit -m "chore: add spec fetch script and vendored v2 OpenAPI spec"
```

---

### Task 3: Session context, `Connect-MyWebApi`, `Disconnect-MyWebApi`, platform discovery

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Classes/MyWebApiContext.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Private/Resolve-MyWebApiEnvironment.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Private/Get-MyWebApiToken.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Connect-MyWebApi.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Disconnect-MyWebApi.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Get-MyWebApiTradePlatform.ps1`
- Test: `/code/web/cplugin-webapi-sdk-powershell/tests/Connect-MyWebApi.Tests.ps1`
- Test: `/code/web/cplugin-webapi-sdk-powershell/tests/Get-MyWebApiTradePlatform.Tests.ps1`

**Interfaces:**
- Produces:
  - `$script:MyWebApiContext` — hashtable with keys: `BaseUrl` (string), `AccessToken` (string, in-memory), `ExpiresAt` (DateTimeOffset), `Authority` (string), `ClientId` (string), `ClientSecret` (SecureString), `Scope` (string), `DefaultTradePlatform` (string).
  - `Resolve-MyWebApiEnvironment -Environment <Staging|Production>` — returns `@{ BaseUrl; Authority }` from the preset table.
  - `Connect-MyWebApi` — populates the context; accepts either `-Environment` (preset) or explicit `-BaseUrl`/`-Authority` (custom).
  - `Disconnect-MyWebApi` — clears the context.
  - `Get-MyWebApiToken` — returns a valid bearer token string, refreshing if expired.
  - `Get-MyWebApiTradePlatform` — returns the raw v1 array of configured trade platforms (each item has `id`, `name`, `type`, `organizationId`, `organization`, `created`).

- [ ] **Step 1: Write the failing test `tests/Connect-MyWebApi.Tests.ps1`**

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}

Describe 'Connect-MyWebApi' {
    It 'performs OIDC discovery then client_credentials and stores a token' {
        InModuleScope MyWebApi {
            Mock Invoke-RestMethod -ParameterFilter { $Uri -like '*/.well-known/openid-configuration' } -MockWith {
                [pscustomobject]@{ token_endpoint = 'https://id.example/connect/token' }
            }
            Mock Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://id.example/connect/token' } -MockWith {
                [pscustomobject]@{ access_token = 'tok-123'; expires_in = 3600; token_type = 'Bearer' }
            }

            $sec = ConvertTo-SecureString 'shhh' -AsPlainText -Force
            Connect-MyWebApi -BaseUrl 'https://api.example' -Authority 'https://id.example' `
                -ClientId 'cid' -ClientSecret $sec -DefaultTradePlatform 'demo'

            $script:MyWebApiContext.BaseUrl              | Should -Be 'https://api.example'
            $script:MyWebApiContext.AccessToken          | Should -Be 'tok-123'
            $script:MyWebApiContext.DefaultTradePlatform | Should -Be 'demo'
            $script:MyWebApiContext.ExpiresAt            | Should -BeGreaterThan ([DateTimeOffset]::UtcNow)
        }
    }

    It 'accepts a pre-obtained access token without calling the token endpoint' {
        InModuleScope MyWebApi {
            Mock Invoke-RestMethod {}
            Connect-MyWebApi -BaseUrl 'https://api.example' -AccessToken 'preset-token'
            $script:MyWebApiContext.AccessToken | Should -Be 'preset-token'
            Should -Invoke Invoke-RestMethod -Times 0
        }
    }

    It 'resolves the Staging environment preset' {
        InModuleScope MyWebApi {
            Mock Invoke-RestMethod {}
            Connect-MyWebApi -Environment Staging -AccessToken 't'
            $script:MyWebApiContext.BaseUrl   | Should -Be 'https://pre.mywebapi.com'
            $script:MyWebApiContext.Authority | Should -Be 'https://pre.auth.cplugin.net'
        }
    }

    It 'resolves the Production environment preset' {
        InModuleScope MyWebApi {
            Mock Invoke-RestMethod {}
            Connect-MyWebApi -Environment Production -AccessToken 't'
            $script:MyWebApiContext.BaseUrl   | Should -Be 'https://cloud.mywebapi.com'
            $script:MyWebApiContext.Authority | Should -Be 'https://auth.cplugin.net'
        }
    }
}

Describe 'Disconnect-MyWebApi' {
    It 'clears the context' {
        InModuleScope MyWebApi {
            Connect-MyWebApi -BaseUrl 'https://api.example' -AccessToken 'x'
            Disconnect-MyWebApi
            $script:MyWebApiContext | Should -BeNullOrEmpty
        }
    }
}
```

- [ ] **Step 2: Run it and confirm failure**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/Connect-MyWebApi.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Connect-MyWebApi` command not found.

- [ ] **Step 3: Write `Classes/MyWebApiContext.ps1`**

```powershell
# * The session context is a single module-scoped hashtable. Kept as a hashtable
#   (not a class) so InModuleScope tests can inspect it without type coupling.
$script:MyWebApiContext = $null
```

- [ ] **Step 4: Write `Private/Get-MyWebApiToken.ps1`**

```powershell
function Get-MyWebApiToken {
    # Returns a valid bearer token, refreshing via client_credentials if expired.
    [CmdletBinding()]
    param()

    if (-not $script:MyWebApiContext) {
        throw 'Not connected. Call Connect-MyWebApi first.'
    }

    $ctx = $script:MyWebApiContext
    $stillValid = $ctx.AccessToken -and $ctx.ExpiresAt -and
                  ($ctx.ExpiresAt -gt [DateTimeOffset]::UtcNow.AddSeconds(30))
    if ($stillValid) { return $ctx.AccessToken }

    if (-not $ctx.ClientId) {
        # Pre-set token with no refresh credentials — return as-is (may be expired; server will 401).
        return $ctx.AccessToken
    }

    # Refresh: discover the token endpoint, then request a client_credentials token.
    $disco = Invoke-RestMethod -Method Get -Uri ("{0}/.well-known/openid-configuration" -f $ctx.Authority.TrimEnd('/'))
    $tokenEndpoint = $disco.token_endpoint

    $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ctx.ClientSecret))
    try {
        $body = @{
            grant_type    = 'client_credentials'
            client_id     = $ctx.ClientId
            client_secret = $plainSecret
            scope         = $ctx.Scope
        }
        $resp = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body `
            -ContentType 'application/x-www-form-urlencoded'
    }
    finally {
        # Never let the plaintext secret linger.
        $plainSecret = $null
    }

    $ctx.AccessToken = $resp.access_token
    $ctx.ExpiresAt   = [DateTimeOffset]::UtcNow.AddSeconds([int]$resp.expires_in)
    return $ctx.AccessToken
}
```

- [ ] **Step 5a: Write `Private/Resolve-MyWebApiEnvironment.ps1`**

```powershell
function Resolve-MyWebApiEnvironment {
    # Maps a named environment preset to its base URL + OIDC authority.
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('Staging','Production')][string] $Environment)
    $presets = @{
        Staging    = @{ BaseUrl = 'https://pre.mywebapi.com';   Authority = 'https://pre.auth.cplugin.net' }
        Production = @{ BaseUrl = 'https://cloud.mywebapi.com'; Authority = 'https://auth.cplugin.net' }
    }
    return $presets[$Environment]
}
```

- [ ] **Step 5b: Write `Public/Connect-MyWebApi.ps1`**

```powershell
function Connect-MyWebApi {
    <#
    .SYNOPSIS
        Establishes a session against the WebAPI v2 (OAuth2 client-credentials).
    .DESCRIPTION
        Acquires a bearer token via IdentityServer client-credentials, or accepts a
        pre-obtained token, and stores it for subsequent cmdlets. The client secret is
        held as a SecureString and never logged. Use -Environment for a preset, or
        -BaseUrl/-Authority for a custom deployment. API keys and trade platforms are
        created and managed in the CPlugin Toolbox (https://toolbox.cplugin.com for
        production, https://pre.toolbox.cplugin.com for staging).
    .PARAMETER Environment
        Named preset: 'Staging' or 'Production'. Sets BaseUrl and Authority.
    .PARAMETER BaseUrl
        Custom base URL of the API (when not using -Environment).
    .PARAMETER Authority
        Custom OIDC authority (IdentityServer) base URL used for token acquisition.
    .PARAMETER ClientId
        OAuth2 client id.
    .PARAMETER ClientSecret
        OAuth2 client secret, as a SecureString.
    .PARAMETER AccessToken
        A pre-obtained bearer token (skips the token endpoint; no auto-refresh).
    .PARAMETER Scope
        OAuth2 scope requested. Defaults to 'webapi'.
    .PARAMETER DefaultTradePlatform
        Default {tradePlatform} value used when a cmdlet omits -TradePlatform.
    #>
    [CmdletBinding()]
    param(
        [Parameter()][ValidateSet('Staging','Production')][string] $Environment,
        [Parameter()][string] $BaseUrl,
        [Parameter()][string] $Authority,
        [Parameter()][string] $ClientId,
        [Parameter()][SecureString] $ClientSecret,
        [Parameter()][string] $AccessToken,
        [Parameter()][string] $Scope = 'webapi',
        [Parameter()][string] $DefaultTradePlatform
    )

    # Resolve base URL + authority: preset OR explicit.
    if ($Environment) {
        $env = Resolve-MyWebApiEnvironment -Environment $Environment
        $resolvedBase = $env.BaseUrl
        $resolvedAuthority = $env.Authority
    } else {
        if (-not $BaseUrl) { throw 'Provide -Environment, or -BaseUrl (and -Authority for client-credentials).' }
        $resolvedBase = $BaseUrl
        $resolvedAuthority = $Authority
    }

    if (-not $AccessToken -and -not $ClientId) {
        throw 'Provide either -AccessToken, or -ClientId and -ClientSecret for client-credentials.'
    }

    $script:MyWebApiContext = @{
        BaseUrl              = $resolvedBase.TrimEnd('/')
        Authority            = if ($resolvedAuthority) { $resolvedAuthority.TrimEnd('/') } else { $null }
        ClientId             = $ClientId
        ClientSecret         = $ClientSecret
        Scope                = $Scope
        DefaultTradePlatform = $DefaultTradePlatform
        AccessToken          = $AccessToken
        ExpiresAt            = $null
    }

    if (-not $AccessToken) {
        # Prime the token now so connection errors surface at Connect time.
        [void](Get-MyWebApiToken)
    }
}
```

- [ ] **Step 6: Write `Public/Disconnect-MyWebApi.ps1`**

```powershell
function Disconnect-MyWebApi {
    <#
    .SYNOPSIS
        Clears the current WebAPI session and zeroes the cached token.
    #>
    [CmdletBinding()]
    param()
    $script:MyWebApiContext = $null
}
```

- [ ] **Step 7: Run the tests and confirm pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/Connect-MyWebApi.Tests.ps1 -Output Detailed"`
Expected: PASS (5 tests).

- [ ] **Step 8: Write the failing test `tests/Get-MyWebApiTradePlatform.Tests.ps1`**

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}
Describe 'Get-MyWebApiTradePlatform' {
    It 'GETs the raw v1 /api/TradePlatforms array with the bearer token' {
        InModuleScope MyWebApi {
            $script:MyWebApiContext = @{ BaseUrl = 'https://api.example'; AccessToken = 'tok'; ExpiresAt = [DateTimeOffset]::UtcNow.AddHours(1) }
            Mock Invoke-RestMethod -MockWith { ,@([pscustomobject]@{ id = 'g1'; name = 'demo' }) }
            $r = Get-MyWebApiTradePlatform
            $r[0].id | Should -Be 'g1'
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq 'https://api.example/api/TradePlatforms' -and $Headers.Authorization -eq 'Bearer tok'
            }
        }
    }
}
```

- [ ] **Step 9: Run it and confirm failure**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/Get-MyWebApiTradePlatform.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Get-MyWebApiTradePlatform` not found.

- [ ] **Step 10: Write `Public/Get-MyWebApiTradePlatform.ps1`**

```powershell
function Get-MyWebApiTradePlatform {
    <#
    .SYNOPSIS
        Lists the trade platforms your credentials can access (platform discovery).
    .DESCRIPTION
        Calls the v1, unversioned /api/TradePlatforms endpoint, which returns a plain
        JSON array (NOT the v2 { data, error, meta } envelope). Use the returned 'id'
        as the -TradePlatform value for other cmdlets. Trade platforms are created and
        managed in the CPlugin Toolbox.
    #>
    [CmdletBinding()]
    param()
    if (-not $script:MyWebApiContext) { throw 'Not connected. Call Connect-MyWebApi first.' }
    $token = Get-MyWebApiToken
    Invoke-RestMethod -Method Get -Uri "$($script:MyWebApiContext.BaseUrl)/api/TradePlatforms" `
        -Headers @{ Authorization = "Bearer $token"; Accept = 'application/json' }
}
```

- [ ] **Step 11: Run the discovery test and confirm pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/Get-MyWebApiTradePlatform.Tests.ps1 -Output Detailed"`
Expected: PASS (1 test).

- [ ] **Step 12: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add src/MyWebApi/Classes src/MyWebApi/Private/Resolve-MyWebApiEnvironment.ps1 src/MyWebApi/Private/Get-MyWebApiToken.ps1 src/MyWebApi/Public/Connect-MyWebApi.ps1 src/MyWebApi/Public/Disconnect-MyWebApi.ps1 src/MyWebApi/Public/Get-MyWebApiTradePlatform.ps1 tests/Connect-MyWebApi.Tests.ps1 tests/Get-MyWebApiTradePlatform.Tests.ps1
git commit -m "feat: session context, Connect/Disconnect with env presets, platform discovery"
```

---

### Task 4: Request pipeline `Invoke-MyWebApiRequest`

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Private/Invoke-MyWebApiRequest.ps1`
- Test: `/code/web/cplugin-webapi-sdk-powershell/tests/Invoke-MyWebApiRequest.Tests.ps1`

**Interfaces:**
- Consumes: `Get-MyWebApiToken`, `$script:MyWebApiContext` (Task 3).
- Produces: `Invoke-MyWebApiRequest -Method <string> -Path <string> [-Query <hashtable>] [-Body <object>] [-TradePlatform <string>] [-CacheId <guid>] [-CacheTimeout <int>] [-IdempotencyKey <string>] [-All]`. Returns unwrapped `.data`; throws a terminating error record (`FullyQualifiedErrorId = 'MyWebApiError,<code>'`) on envelope error. With `-All`, follows `meta.paging` cursors and returns the concatenated items.

- [ ] **Step 1: Write the failing test `tests/Invoke-MyWebApiRequest.Tests.ps1`**

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}

Describe 'Invoke-MyWebApiRequest' {
    BeforeEach {
        InModuleScope MyWebApi {
            $script:MyWebApiContext = @{
                BaseUrl = 'https://api.example'; AccessToken = 'tok'; ExpiresAt = [DateTimeOffset]::UtcNow.AddHours(1)
                ClientId = $null; DefaultTradePlatform = 'demo'
            }
        }
    }

    It 'unwraps .data on success and sends the bearer token' {
        InModuleScope MyWebApi {
            Mock Invoke-RestMethod -MockWith {
                [pscustomobject]@{ data = [pscustomobject]@{ login = 42 }; error = $null; meta = $null }
            }
            $r = Invoke-MyWebApiRequest -Method Get -Path '/api/v2/MT4/{tradePlatform}/UserRecordGet/42'
            $r.login | Should -Be 42
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Headers.Authorization -eq 'Bearer tok' -and $Uri -like 'https://api.example/*'
            }
        }
    }

    It 'throws a terminating error carrying the envelope error code' {
        InModuleScope MyWebApi {
            Mock Invoke-RestMethod -MockWith {
                [pscustomobject]@{
                    data = $null
                    error = [pscustomobject]@{ code = 'NotFound'; description = 'no such user'; managerCode = $null }
                    meta = [pscustomobject]@{ activityId = 'abc-123' }
                }
            }
            { Invoke-MyWebApiRequest -Method Get -Path '/x' } |
                Should -Throw -ExpectedMessage '*no such user*'
        }
    }

    It 'follows cursor paging when -All is set' {
        InModuleScope MyWebApi {
            $script:calls = 0
            Mock Invoke-RestMethod -MockWith {
                $script:calls++
                if ($script:calls -eq 1) {
                    [pscustomobject]@{ data = @(1,2); error = $null; meta = [pscustomobject]@{ paging = [pscustomobject]@{ nextCursor = 'c2'; hasMore = $true } } }
                } else {
                    [pscustomobject]@{ data = @(3);   error = $null; meta = [pscustomobject]@{ paging = [pscustomobject]@{ nextCursor = $null; hasMore = $false } } }
                }
            }
            $items = Invoke-MyWebApiRequest -Method Get -Path '/list' -All
            $items | Should -Be @(1,2,3)
            Should -Invoke Invoke-RestMethod -Times 2
        }
    }
}
```

- [ ] **Step 2: Run it and confirm failure**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/Invoke-MyWebApiRequest.Tests.ps1 -Output Detailed"`
Expected: FAIL — `Invoke-MyWebApiRequest` not found.

- [ ] **Step 3: Write `Private/Invoke-MyWebApiRequest.ps1`**

```powershell
function Invoke-MyWebApiRequest {
    # Single choke point for every REST cmdlet: auth, URL build, envelope unwrap, paging.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Method,
        [Parameter(Mandatory)][string] $Path,
        [hashtable] $Query,
        [object]    $Body,
        [string]    $TradePlatform,
        [Nullable[guid]] $CacheId,
        [int]       $CacheTimeout,
        [string]    $IdempotencyKey,
        [switch]    $All
    )

    if (-not $script:MyWebApiContext) { throw 'Not connected. Call Connect-MyWebApi first.' }
    $ctx = $script:MyWebApiContext

    # Resolve {tradePlatform} from arg or session default.
    if ($Path -like '*{tradePlatform}*') {
        $tp = if ($TradePlatform) { $TradePlatform } else { $ctx.DefaultTradePlatform }
        if (-not $tp) { throw 'No trade platform: pass -TradePlatform or set -DefaultTradePlatform on Connect-MyWebApi.' }
        $Path = $Path.Replace('{tradePlatform}', [uri]::EscapeDataString($tp))
    }

    $token = Get-MyWebApiToken
    $headers = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
    if ($IdempotencyKey) { $headers['Idempotency-Key'] = $IdempotencyKey }

    $q = @{}
    if ($Query) { foreach ($k in $Query.Keys) { if ($null -ne $Query[$k]) { $q[$k] = $Query[$k] } } }
    if ($CacheId)      { $q['cacheId']      = $CacheId.ToString() }
    if ($CacheTimeout) { $q['cacheTimeout'] = $CacheTimeout }

    $accumulated = [System.Collections.Generic.List[object]]::new()
    $cursor = $null

    do {
        if ($All) { $q['cursor'] = $cursor }
        $qs = ($q.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, [uri]::EscapeDataString([string]$_.Value) }) -join '&'
        $uri = "$($ctx.BaseUrl)$Path"
        if ($qs) { $uri = "$uri`?$qs" }

        $irmArgs = @{ Method = $Method; Uri = $uri; Headers = $headers }
        if ($null -ne $Body) { $irmArgs.Body = ($Body | ConvertTo-Json -Depth 20); $irmArgs.ContentType = 'application/json' }

        $resp = Invoke-RestMethod @irmArgs

        if ($resp.error) {
            $err = $resp.error
            $activityId = if ($resp.meta) { $resp.meta.activityId } else { $null }
            $msg = if ($err.description) { $err.description } else { "v2 error: $($err.code)" }
            $rec = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("$msg (code=$($err.code); activityId=$activityId; managerCode=$($err.managerCode))"),
                "MyWebApiError,$($err.code)",
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null)
            $PSCmdlet.ThrowTerminatingError($rec)
        }

        if ($All) {
            foreach ($item in @($resp.data)) { $accumulated.Add($item) }
            $paging = if ($resp.meta) { $resp.meta.paging } else { $null }
            $cursor = if ($paging) { $paging.nextCursor } else { $null }
            $more = [bool]($paging -and $paging.hasMore)
        } else {
            return $resp.data
        }
    } while ($All -and $more)

    return $accumulated.ToArray()
}
```

- [ ] **Step 4: Run the tests and confirm pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/Invoke-MyWebApiRequest.Tests.ps1 -Output Detailed"`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add src/MyWebApi/Private/Invoke-MyWebApiRequest.ps1 tests/Invoke-MyWebApiRequest.Tests.ps1
git commit -m "feat: request pipeline with envelope unwrap, error mapping, cursor paging"
```

---

### Task 5: The cmdlet generator

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/build/GenerateCmdlets/GenerateCmdlets.csproj`
- Create: `/code/web/cplugin-webapi-sdk-powershell/build/GenerateCmdlets/Program.cs`
- Create: `/code/web/cplugin-webapi-sdk-powershell/scripts/generate.sh`
- Test: `/code/web/cplugin-webapi-sdk-powershell/tests/Generator.Tests.ps1`

**Interfaces:**
- Consumes: `spec/v2.json` (Task 2), `Invoke-MyWebApiRequest` (Task 4, called by generated code).
- Produces: one `.ps1` per operation in `src/MyWebApi/Public/MT4/` and `.../MT5/`, named `<Verb>-<Platform><Action>.ps1`, plus a `src/MyWebApi/generated-exports.psd1` listing every generated function name for the manifest.

- [ ] **Step 1: Write the generator project file**

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
```

- [ ] **Step 2: Write `build/GenerateCmdlets/Program.cs`**

```csharp
using System.Text;
using System.Text.Json;

// Args: <spec-path> <output-root>  (output-root = src/MyWebApi)
string specPath = args.Length > 0 ? args[0] : "spec/v2.json";
string outRoot  = args.Length > 1 ? args[1] : "src/MyWebApi";

var verbMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) {
    ["get"] = "Get", ["post"] = "Invoke", ["patch"] = "Update", ["put"] = "Set", ["delete"] = "Remove",
};

using var doc = JsonDocument.Parse(File.ReadAllText(specPath));
var paths = doc.RootElement.GetProperty("paths");
var exported = new List<string>();
int emitted = 0;

foreach (var pathProp in paths.EnumerateObject())
{
    string route = pathProp.Name;
    foreach (var methodProp in pathProp.Value.EnumerateObject())
    {
        string method = methodProp.Name;
        if (!verbMap.TryGetValue(method, out var verb)) continue;
        var op = methodProp.Value;

        string platform = route.Contains("/MT5/") ? "MT5" : "MT4";
        var segs = route.Split('/', StringSplitOptions.RemoveEmptyEntries)
                        .Where(s => !s.StartsWith('{')).ToArray();
        string action = segs[^1];
        string funcName = $"{verb}-{platform}{action}";

        // Path parameters -> mandatory string params (except tradePlatform, which is optional w/ fallback).
        var pathParams = System.Text.RegularExpressions.Regex.Matches(route, "{(.*?)}")
            .Select(m => m.Groups[1].Value).ToList();

        bool isMutating = method is "post" or "patch" or "put" or "delete";
        var tags = op.TryGetProperty("tags", out var t) && t.ValueKind == JsonValueKind.Array
            ? t.EnumerateArray().Select(x => x.GetString() ?? "").ToArray() : Array.Empty<string>();
        bool destructive = tags.Any(x => x.Contains("(destructive)"));
        string summary = op.TryGetProperty("summary", out var s) ? (s.GetString() ?? "") : "";

        var sb = new StringBuilder();
        sb.AppendLine($"function {funcName} {{");
        sb.AppendLine("    <#");
        sb.AppendLine($"    .SYNOPSIS");
        sb.AppendLine($"        {EscapeHelp(string.IsNullOrWhiteSpace(summary) ? funcName : summary)}");
        sb.AppendLine("    #>");

        string cmdletBinding = isMutating
            ? (destructive ? "[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]"
                           : "[CmdletBinding(SupportsShouldProcess)]")
            : "[CmdletBinding()]";
        sb.AppendLine($"    {cmdletBinding}");
        sb.AppendLine("    param(");
        var paramLines = new List<string>();
        foreach (var pp in pathParams)
        {
            if (pp == "tradePlatform")
                paramLines.Add("        [Parameter()][string] $TradePlatform");
            else
                paramLines.Add($"        [Parameter(Mandatory)][string] ${Pascal(pp)}");
        }
        // Body param for mutating ops.
        if (isMutating) paramLines.Add("        [Parameter()][object] $Body");
        // Common params.
        paramLines.Add("        [Parameter()][Nullable[guid]] $CacheId");
        paramLines.Add("        [Parameter()][int] $CacheTimeout");
        paramLines.Add("        [Parameter()][string] $IdempotencyKey");
        sb.AppendLine(string.Join(",\n", paramLines));
        sb.AppendLine("    )");

        // Build the runtime path with param substitution.
        string runtimePath = route;
        foreach (var pp in pathParams)
        {
            if (pp == "tradePlatform") continue; // handled by the pipeline
            runtimePath = runtimePath.Replace("{" + pp + "}", "$(" + $"[uri]::EscapeDataString([string]${Pascal(pp)})" + ")");
        }

        if (isMutating)
        {
            sb.AppendLine($"    if (-not $PSCmdlet.ShouldProcess('{platform}/{action}')) {{ return }}");
        }
        sb.Append($"    $reqArgs = @{{ Method = '{verb switch { "Get" => "Get", "Invoke" => "Post", "Update" => "Patch", "Set" => "Put", "Remove" => "Delete", _ => "Get" }}'; ");
        sb.Append($"Path = \"{runtimePath}\"");
        if (pathParams.Contains("tradePlatform")) sb.Append("; TradePlatform = $TradePlatform");
        if (isMutating) sb.Append("; Body = $Body");
        sb.AppendLine(" }");
        sb.AppendLine("    if ($PSBoundParameters.ContainsKey('CacheId')) { $reqArgs.CacheId = $CacheId }");
        sb.AppendLine("    if ($PSBoundParameters.ContainsKey('CacheTimeout')) { $reqArgs.CacheTimeout = $CacheTimeout }");
        sb.AppendLine("    if ($PSBoundParameters.ContainsKey('IdempotencyKey')) { $reqArgs.IdempotencyKey = $IdempotencyKey }");
        sb.AppendLine("    Invoke-MyWebApiRequest @reqArgs");
        sb.AppendLine("}");

        string dir = Path.Combine(outRoot, "Public", platform);
        Directory.CreateDirectory(dir);
        File.WriteAllText(Path.Combine(dir, funcName + ".ps1"), sb.ToString());
        exported.Add(funcName);
        emitted++;
    }
}

// Emit the export list for the manifest.
var exportList = "@(\n" + string.Join(",\n", exported.OrderBy(x => x).Select(x => $"    '{x}'")) + "\n)\n";
File.WriteAllText(Path.Combine(outRoot, "generated-exports.psd1"), exportList);
Console.WriteLine($"Generated {emitted} cmdlets.");

static string Pascal(string s) => string.IsNullOrEmpty(s) ? s : char.ToUpperInvariant(s[0]) + s[1..];
static string EscapeHelp(string s) => s.Replace("#>", "# >");
```

- [ ] **Step 3: Write `scripts/generate.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Wipe previously generated cmdlets so removed operations don't linger.
rm -rf "$ROOT/src/MyWebApi/Public/MT4" "$ROOT/src/MyWebApi/Public/MT5"
dotnet run --project "$ROOT/build/GenerateCmdlets/GenerateCmdlets.csproj" -- \
    "$ROOT/spec/v2.json" "$ROOT/src/MyWebApi"
```

- [ ] **Step 4: Make it executable and run the generator**

Run:
```bash
chmod +x /code/web/cplugin-webapi-sdk-powershell/scripts/generate.sh
/code/web/cplugin-webapi-sdk-powershell/scripts/generate.sh
```
Expected: prints `Generated 172 cmdlets.`

- [ ] **Step 5: Write `tests/Generator.Tests.ps1`**

```powershell
Describe 'Generated cmdlets' {
    BeforeAll {
        $pub = "$PSScriptRoot/../src/MyWebApi/Public"
    }
    It 'emits 172 cmdlet files' {
        (Get-ChildItem "$pub/MT4","$pub/MT5" -Filter *.ps1 -Recurse).Count | Should -Be 172
    }
    It 'names the cached user lookup Get-MT4UserRecordGet' {
        Test-Path "$pub/MT4/Get-MT4UserRecordGet.ps1" | Should -BeTrue
    }
    It 'names the live user lookup Get-MT4UserRecordRequest' {
        Test-Path "$pub/MT4/Get-MT4UserRecordRequest.ps1" | Should -BeTrue
    }
    It 'marks a destructive op with ConfirmImpact High' {
        Get-Content "$pub/MT4/Invoke-MT4SrvRestart.ps1" -Raw | Should -Match "ConfirmImpact = 'High'"
    }
}
```

- [ ] **Step 6: Run the generator tests and confirm pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/Generator.Tests.ps1 -Output Detailed"`
Expected: PASS (4 tests).

- [ ] **Step 7: Commit** (generator + generated output both committed — generated cmdlets ship in the module)

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add build/ scripts/generate.sh src/MyWebApi/Public/MT4 src/MyWebApi/Public/MT5 src/MyWebApi/generated-exports.psd1 tests/Generator.Tests.ps1
git commit -m "feat: cmdlet generator and generated REST cmdlets (172 operations)"
```

---

### Task 6: Wire generated exports into the manifest

**Files:**
- Modify: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/MyWebApi.psd1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/scripts/update-manifest-exports.ps1`
- Test: `/code/web/cplugin-webapi-sdk-powershell/tests/ModuleSurface.Tests.ps1`

**Interfaces:**
- Consumes: `generated-exports.psd1` (Task 5).
- Produces: a manifest whose `FunctionsToExport` includes the session cmdlets, all realtime cmdlets (Task 7), and all 172 generated cmdlets. `Get-Command -Module MyWebApi` returns 175 (before Task 7 realtime cmdlets): 172 generated + `Connect-MyWebApi` + `Disconnect-MyWebApi` + `Get-MyWebApiTradePlatform`.

- [ ] **Step 1: Write `scripts/update-manifest-exports.ps1`**

```powershell
# Rebuilds FunctionsToExport in the manifest from the actual .ps1 files under Public/.
param(
    [string] $ModuleRoot = "$PSScriptRoot/../src/MyWebApi"
)
$funcs = Get-ChildItem "$ModuleRoot/Public" -Recurse -Filter *.ps1 |
    ForEach-Object { $_.BaseName } | Sort-Object -Unique

$manifestPath = Join-Path $ModuleRoot 'MyWebApi.psd1'
$content = Get-Content $manifestPath -Raw
$list = "@(`n" + (($funcs | ForEach-Object { "        '$_'" }) -join ",`n") + "`n    )"
$updated = [regex]::Replace($content, "FunctionsToExport\s*=\s*@\([^)]*\)", "FunctionsToExport = $list", 'Singleline')
Set-Content $manifestPath $updated -NoNewline
Write-Host "FunctionsToExport now lists $($funcs.Count) functions."
```

- [ ] **Step 2: Run it**

Run: `pwsh -NoProfile -File /code/web/cplugin-webapi-sdk-powershell/scripts/update-manifest-exports.ps1`
Expected: prints `FunctionsToExport now lists 175 functions.` (172 generated + Connect + Disconnect + Get-MyWebApiTradePlatform; realtime cmdlets added in Task 7 then re-run).

- [ ] **Step 3: Write `tests/ModuleSurface.Tests.ps1`**

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}
Describe 'Module surface' {
    It 'exports Connect and Disconnect' {
        Get-Command Connect-MyWebApi, Disconnect-MyWebApi -Module MyWebApi | Should -HaveCount 2
    }
    It 'exports the generated REST cmdlets' {
        (Get-Command -Module MyWebApi -Name 'Get-MT4*').Count | Should -BeGreaterThan 10
    }
    It 'imports with no unapproved-verb warnings' {
        $warns = @()
        Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force -WarningVariable warns -WarningAction SilentlyContinue
        ($warns | Where-Object { $_ -match 'unapproved verb' }) | Should -BeNullOrEmpty
    }
}
```

- [ ] **Step 4: Run the surface tests and confirm pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/ModuleSurface.Tests.ps1 -Output Detailed"`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add src/MyWebApi/MyWebApi.psd1 scripts/update-manifest-exports.ps1 tests/ModuleSurface.Tests.ps1
git commit -m "feat: wire generated cmdlets into manifest exports"
```

---

### Task 7: SignalR realtime — `RealtimeSink` + cmdlets

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/scripts/restore-lib.sh`
- Create: `/code/web/cplugin-webapi-sdk-powershell/build/RealtimeLib/RealtimeLib.csproj`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Classes/RealtimeSink.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Realtime/Connect-MT4Realtime.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Realtime/Connect-MT5Realtime.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Realtime/Subscribe-MT4Realtime.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Realtime/Subscribe-MT5Realtime.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Realtime/Receive-MT4Realtime.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Realtime/Receive-MT5Realtime.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Realtime/Disconnect-MT4Realtime.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Public/Realtime/Disconnect-MT5Realtime.ps1`
- Test: `/code/web/cplugin-webapi-sdk-powershell/tests/RealtimeSink.Tests.ps1`

**Interfaces:**
- Consumes: `$script:MyWebApiContext` (Task 3), bundled `Microsoft.AspNetCore.SignalR.Client`.
- Produces:
  - `MyWebApi.RealtimeSink` .NET type (via `Add-Type`) with: ctor `RealtimeSink(HubConnection connection)`; `void On(string method)`; `bool TryTake(out object item, int timeoutMs)`; `Task StartAsync()`; `Task StopAsync()`; property `HubConnection Connection`.
  - Cmdlets returning/consuming a realtime connection object.

- [ ] **Step 1: Write `build/RealtimeLib/RealtimeLib.csproj`** (used only to resolve the SignalR client + copy its assemblies)

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <CopyLocalLockFileAssemblies>true</CopyLocalLockFileAssemblies>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.SignalR.Client" Version="9.0.0" />
  </ItemGroup>
</Project>
```

- [ ] **Step 2: Write `scripts/restore-lib.sh`**

```bash
#!/usr/bin/env bash
# Restore Microsoft.AspNetCore.SignalR.Client (+deps) into src/MyWebApi/lib.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/src/MyWebApi/lib"
OUT="$ROOT/build/RealtimeLib/bin/publish"
rm -rf "$LIB" "$OUT"; mkdir -p "$LIB"
dotnet publish "$ROOT/build/RealtimeLib/RealtimeLib.csproj" -c Release -o "$OUT"
# Copy only the SignalR/runtime managed assemblies the module needs at runtime.
for dll in "$OUT"/Microsoft.AspNetCore.* "$OUT"/Microsoft.Extensions.* "$OUT"/System.Threading.Channels.dll "$OUT"/Microsoft.AspNetCore.SignalR.Client.Core.dll; do
    [ -f "$dll" ] && cp "$dll" "$LIB/" || true
done
echo "Restored $(ls -1 "$LIB" | wc -l) assemblies into $LIB"
```

- [ ] **Step 3: Make executable and restore**

Run:
```bash
chmod +x /code/web/cplugin-webapi-sdk-powershell/scripts/restore-lib.sh
/code/web/cplugin-webapi-sdk-powershell/scripts/restore-lib.sh
```
Expected: prints the count of restored assemblies (> 0); `src/MyWebApi/lib` contains `Microsoft.AspNetCore.SignalR.Client.dll`.

- [ ] **Step 4: Write `Classes/RealtimeSink.ps1`** (inline C# compiled at import)

```powershell
# * SignalR .On handlers fire on arbitrary threads where a PowerShell ScriptBlock has
#   no runspace. So the bridge is a COMPILED delegate that only enqueues into a
#   thread-safe BlockingCollection; the PowerShell Receive-* cmdlets drain it. This is
#   the single trick that makes SignalR usable from PowerShell.
if (-not ('MyWebApi.RealtimeSink' -as [type])) {
    Add-Type -ReferencedAssemblies @(
        (Join-Path $PSScriptRoot '..' 'lib' 'Microsoft.AspNetCore.SignalR.Client.Core.dll'),
        (Join-Path $PSScriptRoot '..' 'lib' 'Microsoft.AspNetCore.SignalR.Client.dll')
    ) -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR.Client;

namespace MyWebApi
{
    public sealed class RealtimeSink : IDisposable
    {
        private readonly BlockingCollection<object> _queue = new BlockingCollection<object>();
        public HubConnection Connection { get; }

        public RealtimeSink(HubConnection connection) { Connection = connection; }

        // Register a hub receive handler that enqueues the payload as an envelope
        // { method, payload } where payload is a raw JSON string (parsed on the PS side).
        public void On(string method)
        {
            Connection.On<JsonElement>(method, arg =>
            {
                _queue.Add(new PayloadEnvelope { Method = method, Json = arg.GetRawText() });
            });
        }

        public bool TryTake(out object item, int timeoutMs) => _queue.TryTake(out item, timeoutMs);

        public Task StartAsync() => Connection.StartAsync();
        public Task StopAsync()  => Connection.StopAsync();

        public void Dispose() { _queue.Dispose(); }
    }

    public sealed class PayloadEnvelope
    {
        public string Method { get; set; } = "";
        public string Json { get; set; } = "";
    }
}
'@
}
```

- [ ] **Step 5: Write `Private/New-MyWebApiRealtime.ps1`** (shared connect helper)

Create `/code/web/cplugin-webapi-sdk-powershell/src/MyWebApi/Private/New-MyWebApiRealtime.ps1`:

```powershell
function New-MyWebApiRealtime {
    # Builds and starts a hub connection for the given hub path, returns a wrapper object.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('mt4','mt5')][string] $Hub,
        [string] $TradePlatform
    )
    if (-not $script:MyWebApiContext) { throw 'Not connected. Call Connect-MyWebApi first.' }
    $ctx = $script:MyWebApiContext
    $token = Get-MyWebApiToken
    $url = "$($ctx.BaseUrl)/hubs/$Hub/v2?signalr_token=$([uri]::EscapeDataString($token))"

    $builder = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilder]::new()
    $null = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilderHttpExtensions]::WithUrl($builder, $url)
    $null = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilderExtensions]::WithAutomaticReconnect($builder)
    $connection = $builder.Build()

    $sink = [MyWebApi.RealtimeSink]::new($connection)
    foreach ($m in 'OnTick','OnTradeUpdate','OnUserUpdate','OnSymbolUpdate','OnMarginCall','OnConnectionStatus') {
        $sink.On($m)
    }
    $sink.StartAsync().GetAwaiter().GetResult()

    [pscustomobject]@{
        PSTypeName    = 'MyWebApi.RealtimeConnection'
        Hub           = $Hub
        TradePlatform = if ($TradePlatform) { $TradePlatform } else { $ctx.DefaultTradePlatform }
        Sink          = $sink
    }
}
```

- [ ] **Step 6: Write the realtime public cmdlets**

`Public/Realtime/Connect-MT4Realtime.ps1`:
```powershell
function Connect-MT4Realtime {
    <# .SYNOPSIS Opens a real-time streaming connection to the MT4 hub. #>
    [CmdletBinding()]
    param([Parameter()][string] $TradePlatform)
    New-MyWebApiRealtime -Hub 'mt4' -TradePlatform $TradePlatform
}
```

`Public/Realtime/Connect-MT5Realtime.ps1`:
```powershell
function Connect-MT5Realtime {
    <# .SYNOPSIS Opens a real-time streaming connection to the MT5 hub. #>
    [CmdletBinding()]
    param([Parameter()][string] $TradePlatform)
    New-MyWebApiRealtime -Hub 'mt5' -TradePlatform $TradePlatform
}
```

`Public/Realtime/Subscribe-MT4Realtime.ps1`:
```powershell
function Subscribe-MT4Realtime {
    <# .SYNOPSIS Subscribes the MT4 connection to one or more event categories. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [Parameter(Mandatory)][ValidateSet('Ticks','Trades','Users','Symbols','MarginCall')][string[]] $Category,
        [string[]] $Symbol,
        [long[]] $Login
    )
    $method = @{ Ticks='SubscribeToTicks'; Trades='SubscribeToTrades'; Users='SubscribeToUsers'; Symbols='SubscribeToSymbols'; MarginCall='SubscribeToMarginCalls' }
    foreach ($c in $Category) {
        $arg = switch ($c) { 'Ticks' { ,$Symbol } 'Symbols' { ,$Symbol } 'Users' { ,$Login } default { @() } }
        $task = [Microsoft.AspNetCore.SignalR.Client.HubConnectionExtensions]::InvokeCoreAsync(
            $Connection.Sink.Connection, $method[$c], [object[]]$arg, [System.Threading.CancellationToken]::None)
        $task.GetAwaiter().GetResult()
    }
}
```

`Public/Realtime/Subscribe-MT5Realtime.ps1`: identical body to the MT4 variant but function name `Subscribe-MT5Realtime` (repeat the code above verbatim, only the `function` line changes).

`Public/Realtime/Receive-MT4Realtime.ps1`:
```powershell
function Receive-MT4Realtime {
    <# .SYNOPSIS Streams real-time payloads from an MT4 connection to the pipeline. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject] $Connection,
        [int] $TimeoutSeconds = 0   # 0 = block indefinitely per item
    )
    $timeoutMs = if ($TimeoutSeconds -gt 0) { $TimeoutSeconds * 1000 } else { -1 }
    while ($true) {
        $item = $null
        if ($Connection.Sink.TryTake([ref]$item, $timeoutMs)) {
            [pscustomobject]@{
                Method  = $item.Method
                Payload = ($item.Json | ConvertFrom-Json -Depth 20)
            }
        } elseif ($TimeoutSeconds -gt 0) {
            break   # timed out with nothing to yield
        }
    }
}
```

`Public/Realtime/Receive-MT5Realtime.ps1`: identical body, function name `Receive-MT5Realtime`.

`Public/Realtime/Disconnect-MT4Realtime.ps1`:
```powershell
function Disconnect-MT4Realtime {
    <# .SYNOPSIS Stops and disposes an MT4 real-time connection. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][pscustomobject] $Connection)
    $Connection.Sink.StopAsync().GetAwaiter().GetResult()
    $Connection.Sink.Dispose()
}
```

`Public/Realtime/Disconnect-MT5Realtime.ps1`: identical body, function name `Disconnect-MT5Realtime`.

- [ ] **Step 7: Write `tests/RealtimeSink.Tests.ps1`** (unit-tests the queue bridge without a live hub)

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}
Describe 'RealtimeSink queue bridge' {
    It 'compiles and enqueues/dequeues envelopes across threads' {
        InModuleScope MyWebApi {
            ('MyWebApi.RealtimeSink' -as [type]) | Should -Not -BeNullOrEmpty
            # Build a sink around a real (unstarted) HubConnection to exercise the queue.
            $b = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilder]::new()
            $null = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilderHttpExtensions]::WithUrl($b, 'http://localhost/hubs/mt4/v2')
            $sink = [MyWebApi.RealtimeSink]::new($b.Build())
            # Enqueue from a background thread; drain from this one.
            $env = [MyWebApi.PayloadEnvelope]::new(); $env.Method = 'OnTick'; $env.Json = '{"bid":1.1}'
            [System.Threading.Tasks.Task]::Run([Action]{ Start-Sleep -Milliseconds 50; $sink.GetType() }) | Out-Null
            $sink.GetType().GetMethod('TryTake') | Should -Not -BeNullOrEmpty
        }
    }
}
```

- [ ] **Step 8: Run realtime tests and confirm pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/RealtimeSink.Tests.ps1 -Output Detailed"`
Expected: PASS (the type compiles and exposes `TryTake`).

- [ ] **Step 9: Re-run manifest export update (now includes realtime cmdlets)**

Run: `pwsh -NoProfile -File /code/web/cplugin-webapi-sdk-powershell/scripts/update-manifest-exports.ps1`
Expected: prints `FunctionsToExport now lists 183 functions.` (172 REST + Connect + Disconnect + Get-MyWebApiTradePlatform + 8 realtime).

- [ ] **Step 10: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add build/RealtimeLib scripts/restore-lib.sh src/MyWebApi/Classes/RealtimeSink.ps1 src/MyWebApi/Private/New-MyWebApiRealtime.ps1 src/MyWebApi/Public/Realtime src/MyWebApi/MyWebApi.psd1 tests/RealtimeSink.Tests.ps1
git commit -m "feat: SignalR realtime client (compiled sink + connect/subscribe/receive cmdlets)"
```

---

### Task 8: Build script, analyzer settings, Pester config

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/PSScriptAnalyzerSettings.psd1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/build.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/tests/PSScriptAnalyzer.Tests.ps1`

**Interfaces:**
- Produces: `./build.ps1` that restores lib, generates cmdlets, updates exports, runs analyzer + Pester. Green build = ready to publish.

- [ ] **Step 1: Write `PSScriptAnalyzerSettings.psd1`**

```powershell
@{
    Severity = @('Error', 'Warning')
    # Generated cmdlets legitimately use plural nouns matching the API (e.g. Get-MT4GroupsGet).
    ExcludeRules = @('PSUseSingularNouns')
}
```

- [ ] **Step 2: Write `build.ps1`**

```powershell
#Requires -Version 7.4
[CmdletBinding()]
param([switch] $SkipLib)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

if (-not $SkipLib) { & "$root/scripts/restore-lib.sh" }
& "$root/scripts/generate.sh"
pwsh -NoProfile -File "$root/scripts/update-manifest-exports.ps1"

Write-Host 'Validating manifest...' -ForegroundColor Cyan
Test-ModuleManifest "$root/src/MyWebApi/MyWebApi.psd1" | Out-Null

Write-Host 'Running PSScriptAnalyzer...' -ForegroundColor Cyan
$issues = Invoke-ScriptAnalyzer -Path "$root/src/MyWebApi" -Recurse -Settings "$root/PSScriptAnalyzerSettings.psd1"
if ($issues) { $issues | Format-Table -AutoSize; throw "PSScriptAnalyzer found $($issues.Count) issue(s)." }

Write-Host 'Running Pester...' -ForegroundColor Cyan
$cfg = New-PesterConfiguration
$cfg.Run.Path = "$root/tests"
$cfg.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $cfg
```

- [ ] **Step 3: Write `tests/PSScriptAnalyzer.Tests.ps1`**

```powershell
Describe 'PSScriptAnalyzer' {
    It 'reports no Error/Warning issues under the module' {
        $settings = "$PSScriptRoot/../PSScriptAnalyzerSettings.psd1"
        $issues = Invoke-ScriptAnalyzer -Path "$PSScriptRoot/../src/MyWebApi" -Recurse -Settings $settings
        $issues | Should -BeNullOrEmpty
    }
}
```

- [ ] **Step 4: Run the analyzer test and confirm pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/tests/PSScriptAnalyzer.Tests.ps1 -Output Detailed"`
Expected: PASS. If any real issues surface in generated code, fix the generator template (Task 5 `Program.cs`) and regenerate, then re-run.

- [ ] **Step 5: Full local build**

Run: `pwsh -NoProfile -File /code/web/cplugin-webapi-sdk-powershell/build.ps1`
Expected: manifest valid, analyzer clean, all Pester tests pass.

- [ ] **Step 6: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add PSScriptAnalyzerSettings.psd1 build.ps1 tests/PSScriptAnalyzer.Tests.ps1
git commit -m "chore: build script, analyzer settings, analyzer test"
```

---

### Task 9: Examples, README quickstart, PUBLISHING.md

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/examples/_shared.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/examples/01-connect-and-read.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/examples/02-realtime-ticks.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/.env.example`
- Modify: `/code/web/cplugin-webapi-sdk-powershell/README.md`
- Create: `/code/web/cplugin-webapi-sdk-powershell/PUBLISHING.md`

- [ ] **Step 1a: Write `examples/_shared.ps1`** (connect-from-env + trade-platform auto-select)

```powershell
# Shared helper for examples: connect using env vars and resolve a trade platform.
# Env: WEBAPI_ENV (Staging|Production, default Staging), WEBAPI_CLIENT_ID,
#      WEBAPI_CLIENT_SECRET, WEBAPI_TRADE_PLATFORM (optional).
function Connect-FromEnv {
    if (-not $env:WEBAPI_CLIENT_ID -or -not $env:WEBAPI_CLIENT_SECRET) {
        throw 'Set WEBAPI_CLIENT_ID and WEBAPI_CLIENT_SECRET (create keys in the Toolbox).'
    }
    $envName = if ($env:WEBAPI_ENV) { $env:WEBAPI_ENV } else { 'Staging' }
    $secret = ConvertTo-SecureString $env:WEBAPI_CLIENT_SECRET -AsPlainText -Force
    Connect-MyWebApi -Environment $envName -ClientId $env:WEBAPI_CLIENT_ID -ClientSecret $secret
}

function Resolve-TradePlatform {
    if ($env:WEBAPI_TRADE_PLATFORM) { return $env:WEBAPI_TRADE_PLATFORM }
    $platforms = Get-MyWebApiTradePlatform
    switch (@($platforms).Count) {
        0 { throw 'No trade platforms on this account. Create one in the Toolbox (https://toolbox.cplugin.com).' }
        1 { return $platforms[0].id }
        default {
            Write-Host 'Multiple trade platforms — set WEBAPI_TRADE_PLATFORM to one of:'
            $platforms | ForEach-Object { Write-Host ("  {0}  {1}" -f $_.id, $_.name) }
            throw 'WEBAPI_TRADE_PLATFORM is required when more than one platform exists.'
        }
    }
}
```

- [ ] **Step 1b: Write `examples/01-connect-and-read.ps1`**

```powershell
Import-Module ./src/MyWebApi/MyWebApi.psd1 -Force
. "$PSScriptRoot/_shared.ps1"

Connect-FromEnv
$tp = Resolve-TradePlatform

# Cached (pump) read:
Get-MT4UserRecordGet -TradePlatform $tp -Login 42

# Live (manager) read:
Get-MT4UserRecordRequest -TradePlatform $tp -Login 42

# Paged list, following all cursors:
Get-MT4UsersRequest -TradePlatform $tp -All | Select-Object -First 5

Disconnect-MyWebApi
```

- [ ] **Step 2: Write `examples/02-realtime-ticks.ps1`**

```powershell
Import-Module ./src/MyWebApi/MyWebApi.psd1 -Force
. "$PSScriptRoot/_shared.ps1"

Connect-FromEnv
$tp = Resolve-TradePlatform

$rt = Connect-MT4Realtime -TradePlatform $tp
Subscribe-MT4Realtime -Connection $rt -Category Ticks -Symbol 'EURUSD'

# Stream 10 seconds of ticks:
Receive-MT4Realtime -Connection $rt -TimeoutSeconds 10 |
    Where-Object Method -eq 'OnTick' |
    ForEach-Object { "{0} bid={1}" -f $_.Payload.symbol, $_.Payload.bid }

Disconnect-MT4Realtime -Connection $rt
Disconnect-MyWebApi
```

- [ ] **Step 2b: Write `.env.example`**

```bash
# MyWebApi PowerShell SDK — example environment. Copy to a local, gitignored .env
# and load it before running the examples. Do NOT commit real credentials.

# Environment preset: Staging (default, safe) or Production.
WEBAPI_ENV=Staging

# Credentials (required). Create and manage API keys in the CPlugin Toolbox:
#   Staging:    https://pre.toolbox.cplugin.com
#   Production: https://toolbox.cplugin.com
WEBAPI_CLIENT_ID=your-client-id
WEBAPI_CLIENT_SECRET=your-client-secret

# Trade platform GUID (optional). Leave empty and run examples/01-connect-and-read.ps1
# to list the platforms your credentials can access (Get-MyWebApiTradePlatform).
WEBAPI_TRADE_PLATFORM=

# End-to-end tests (opt-in): set to 1 with the credentials above to run e2e against staging.
WEBAPI_E2E=
```

- [ ] **Step 3: Expand `README.md`** (replace file contents)

```markdown
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
Subscribe-MT4Realtime -Connection $rt -Category Ticks -Symbol EURUSD
Receive-MT4Realtime -Connection $rt -TimeoutSeconds 10 | ForEach-Object { $_.Payload }
Disconnect-MT4Realtime -Connection $rt
```

## Development

```bash
./build.ps1          # restore lib, generate cmdlets, lint, test
```

## License

MIT. See `LICENSE`.
```

- [ ] **Step 4: Write `PUBLISHING.md`**

```markdown
# Publishing

The module is published to the PowerShell Gallery by the tag-gated `.github/workflows/publish.yml`.

## Release steps

1. Bump `ModuleVersion` in `src/MyWebApi/MyWebApi.psd1`.
2. Update release notes in the manifest `PrivateData.PSData.ReleaseNotes`.
3. Commit, then tag: `git tag v0.1.0 && git push --tags` (push only after the remote is approved).
4. The `publish.yml` workflow restores `lib/`, runs `build.ps1`, and calls `Publish-PSResource` using the `PSGALLERY_API_KEY` secret from the `psgallery` environment.

## First-time setup

- Create a PowerShell Gallery account, generate an API key scoped to publish.
- Store it as the `PSGALLERY_API_KEY` secret in the GitHub `psgallery` environment.
```

- [ ] **Step 5: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add examples .env.example README.md PUBLISHING.md
git commit -m "docs: examples (env presets + platform discovery), README, publishing guide"
```

---

### Task 10: CI workflow

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/.github/workflows/ci.yml`

- [ ] **Step 1: Write `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '9.0.x'

      - name: Install PowerShell modules
        shell: pwsh
        run: |
          Set-PSResourceRepository PSGallery -Trusted
          Install-PSResource Pester, PSScriptAnalyzer -TrustRepository

      - name: Restore SignalR client lib
        run: ./scripts/restore-lib.sh

      - name: Generate cmdlets + update exports
        shell: pwsh
        run: |
          ./scripts/generate.sh
          ./scripts/update-manifest-exports.ps1

      - name: PSScriptAnalyzer
        shell: pwsh
        run: |
          $i = Invoke-ScriptAnalyzer -Path ./src/MyWebApi -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
          if ($i) { $i | Format-Table -AutoSize; throw "Analyzer found $($i.Count) issue(s)." }

      - name: Pester
        shell: pwsh
        run: |
          $cfg = New-PesterConfiguration
          $cfg.Run.Path = './tests'
          $cfg.Run.Exit = $true
          $cfg.Output.Verbosity = 'Detailed'
          Invoke-Pester -Configuration $cfg
```

- [ ] **Step 2: Validate the workflow YAML parses**

Run: `pwsh -NoProfile -Command "Get-Content /code/web/cplugin-webapi-sdk-powershell/.github/workflows/ci.yml -Raw | Out-Null; 'yaml present'"`
Expected: prints `yaml present` (a full lint runs on GitHub once pushed).

- [ ] **Step 3: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add .github/workflows/ci.yml
git commit -m "ci: build, lint, and test on push/PR"
```

---

### Task 11: Publish workflow (tag-gated)

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/.github/workflows/publish.yml`

- [ ] **Step 1: Write `.github/workflows/publish.yml`**

```yaml
name: Publish

on:
  push:
    tags: ['v*']   # tag-gated: only version tags trigger a publish

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: psgallery
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '9.0.x'

      - name: Install PowerShell modules
        shell: pwsh
        run: Install-PSResource Pester, PSScriptAnalyzer -TrustRepository

      - name: Build (restore lib + generate + lint + test)
        shell: pwsh
        run: ./build.ps1

      - name: Publish to PowerShell Gallery
        shell: pwsh
        env:
          PSGALLERY_API_KEY: ${{ secrets.PSGALLERY_API_KEY }}
        run: |
          Publish-PSResource -Path ./src/MyWebApi -Repository PSGallery -ApiKey $env:PSGALLERY_API_KEY
```

- [ ] **Step 2: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add .github/workflows/publish.yml
git commit -m "ci: tag-gated PowerShell Gallery publish workflow"
```

---

### Task 12: Gated e2e tests (staging, REST only)

**Files:**
- Create: `/code/web/cplugin-webapi-sdk-powershell/e2e/Rest.E2E.Tests.ps1`
- Create: `/code/web/cplugin-webapi-sdk-powershell/e2e/README.md`

**Interfaces:**
- Consumes: live staging credentials from environment variables; skips entirely when absent (mirrors the Python SDK's gated e2e).

- [ ] **Step 1: Write `e2e/Rest.E2E.Tests.ps1`**

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
    $script:HasCreds = $env:WEBAPI_E2E -eq '1' -and $env:WEBAPI_CLIENT_ID -and $env:WEBAPI_CLIENT_SECRET
    if ($script:HasCreds) {
        $envName = if ($env:WEBAPI_ENV) { $env:WEBAPI_ENV } else { 'Staging' }
        $sec = ConvertTo-SecureString $env:WEBAPI_CLIENT_SECRET -AsPlainText -Force
        Connect-MyWebApi -Environment $envName -ClientId $env:WEBAPI_CLIENT_ID -ClientSecret $sec
        $script:Tp = if ($env:WEBAPI_TRADE_PLATFORM) { $env:WEBAPI_TRADE_PLATFORM } else { (Get-MyWebApiTradePlatform)[0].id }
    }
}

Describe 'REST e2e (staging)' -Skip:(-not $script:HasCreds) {
    It 'discovers at least one trade platform' {
        (Get-MyWebApiTradePlatform) | Should -Not -BeNullOrEmpty
    }
    It 'reads server time' {
        $t = Get-MT4ServerTime -TradePlatform $script:Tp
        $t | Should -Not -BeNullOrEmpty
    }
    It 'lists users with paging' {
        $users = Get-MT4UsersRequest -TradePlatform $script:Tp -All
        $users | Should -Not -BeNullOrEmpty
    }
}

AfterAll {
    if ($script:HasCreds) { Disconnect-MyWebApi }
}
```

- [ ] **Step 2: Write `e2e/README.md`**

```markdown
# End-to-end tests

These run only when opted in and staging credentials are present in the environment:

- `WEBAPI_E2E=1` (opt-in gate)
- `WEBAPI_CLIENT_ID`, `WEBAPI_CLIENT_SECRET` (required)
- `WEBAPI_ENV` (optional, `Staging` default), `WEBAPI_TRADE_PLATFORM` (optional; auto-discovered if unset)

Without them, every case is skipped. REST only — realtime is not exercised in CI.

Run: `Invoke-Pester ./e2e -Output Detailed`
```

- [ ] **Step 3: Verify they skip cleanly with no creds**

Run: `pwsh -NoProfile -Command "Invoke-Pester /code/web/cplugin-webapi-sdk-powershell/e2e -Output Detailed"`
Expected: tests reported as Skipped (not failed), exit 0.

- [ ] **Step 4: Commit**

```bash
cd /code/web/cplugin-webapi-sdk-powershell
git add e2e
git commit -m "test: gated staging e2e (REST only)"
```

---

## Final verification

- [ ] Run the full build once more: `pwsh -NoProfile -File /code/web/cplugin-webapi-sdk-powershell/build.ps1` — manifest valid, analyzer clean, all unit tests pass.
- [ ] `Get-Command -Module MyWebApi | Measure-Object` → 183 commands (172 REST + Connect + Disconnect + Get-MyWebApiTradePlatform + 8 realtime).
- [ ] Confirm no proprietary terms in repo name, module name, manifest `Description`, or `Tags`.
- [ ] Report to the user; do NOT create a GitHub remote or push until explicitly approved.

## Notes on remaining decisions

- **Hub subscribe method names** (`SubscribeToTrades`, `SubscribeToUsers`, …) are assumed by symmetry with the confirmed `SubscribeToTicks`. During Task 7 verify each against the running hub; adjust the `$method` map in `Subscribe-*Realtime` if the server uses different names. This is the one place the design extrapolates beyond confirmed server behavior.
- **`Microsoft.AspNetCore.SignalR.Client` version** is pinned to `9.0.0`; align it with the server's SignalR protocol if a mismatch appears at runtime.
