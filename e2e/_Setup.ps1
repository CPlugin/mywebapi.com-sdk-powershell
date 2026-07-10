# Shared harness for the e2e suite (dot-sourced by every *.E2E.Tests.ps1 file).
#
# ! Everything below the parameter block runs as TOP-LEVEL STATEMENTS. Pester
#   evaluates `Describe -Skip:(...)` during the DISCOVERY phase, before any
#   BeforeAll/BeforeDiscovery block runs — so the gate flag must already be a
#   real boolean the moment this file is dot-sourced, not something computed
#   later inside a function or BeforeAll.
#
# Required env vars (all three must be set for $script:E2EEnabled to be true):
#   WEBAPI_E2E             — opt-in flag, must be exactly '1'
#   WEBAPI_CLIENT_ID       — OAuth2 client_id (manager credential)
#   WEBAPI_CLIENT_SECRET   — OAuth2 client_secret
#
# Connection target — EITHER of:
#   WEBAPI_BASE_URL + WEBAPI_AUTHORITY   — custom deployment (both required together)
#   WEBAPI_ENV                            — named preset ('Staging'/'Production', default 'Staging')
#
# Optional env vars:
#   WEBAPI_TRADE_PLATFORM       — platform id override; auto-selected when omitted and only one exists
#   WEBAPI_SYMBOL               — symbol for tick streaming (default: EURUSD)
#   WEBAPI_E2E_TICK_TIMEOUT_MS  — ms to wait for the first tick (default: 20000)

$script:E2EEnabled = $env:WEBAPI_E2E -eq '1' -and $env:WEBAPI_CLIENT_ID -and $env:WEBAPI_CLIENT_SECRET
$script:E2ESymbol  = if ($env:WEBAPI_SYMBOL) { $env:WEBAPI_SYMBOL } else { 'EURUSD' }
$script:E2ETickTimeoutSec = [math]::Max(1, [int][math]::Ceiling(([double]$(if ($env:WEBAPI_E2E_TICK_TIMEOUT_MS) { $env:WEBAPI_E2E_TICK_TIMEOUT_MS } else { 20000 })) / 1000))

# * Connects the module against the e2e target described by the environment.
#   Prefers an explicit custom deployment (-BaseUrl/-Authority) when both are
#   set; otherwise falls back to the named preset (-Environment), same as
#   Connect-MyWebApi itself. The secret is wrapped in a SecureString and never
#   written to any log/host stream.
function Connect-E2E {
    [CmdletBinding()]
    param()

    if (-not $script:E2EEnabled) {
        throw 'Connect-E2E called without the e2e gate enabled. Set WEBAPI_E2E=1, WEBAPI_CLIENT_ID and WEBAPI_CLIENT_SECRET.'
    }

    $sec = ConvertTo-SecureString $env:WEBAPI_CLIENT_SECRET -AsPlainText -Force

    if ($env:WEBAPI_BASE_URL -and $env:WEBAPI_AUTHORITY) {
        Connect-MyWebApi -BaseUrl $env:WEBAPI_BASE_URL -Authority $env:WEBAPI_AUTHORITY `
            -ClientId $env:WEBAPI_CLIENT_ID -ClientSecret $sec
    } else {
        $envName = if ($env:WEBAPI_ENV) { $env:WEBAPI_ENV } else { 'Staging' }
        Connect-MyWebApi -Environment $envName -ClientId $env:WEBAPI_CLIENT_ID -ClientSecret $sec
    }
}

# * Resolves the trade platform id to use for this e2e run.
#   Resolution order mirrors the JS SDK's resolveTp():
#     1. WEBAPI_TRADE_PLATFORM env var — explicit override, skips discovery.
#     2. Get-MyWebApiTradePlatform discovery:
#        - zero platforms  -> throw (credential has no accessible platforms)
#        - exactly one     -> return its id
#        - two or more     -> throw, listing every id (set WEBAPI_TRADE_PLATFORM)
function Resolve-E2ETradePlatform {
    [CmdletBinding()]
    param()

    if ($env:WEBAPI_TRADE_PLATFORM) { return $env:WEBAPI_TRADE_PLATFORM }

    $platforms = @(Get-MyWebApiTradePlatform)
    switch ($platforms.Count) {
        0 {
            throw 'E2E: no trade platforms returned for this credential. ' +
                  'Grant the client access to at least one platform in the Toolbox.'
        }
        1 {
            return $platforms[0].id
        }
        default {
            $ids = ($platforms | ForEach-Object { $_.id }) -join ', '
            throw "E2E: multiple trade platforms found [$ids]. Set WEBAPI_TRADE_PLATFORM to one of these IDs."
        }
    }
}
