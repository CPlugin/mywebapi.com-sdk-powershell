# * E2E tests for the SignalR real-time surface of the MyWebApi v2 SDK.
#
# Tests the full lifecycle: OAuth token -> WebSocket handshake -> server push.
#
# ! GATED — every test skips unless WEBAPI_E2E=1 AND WEBAPI_CLIENT_ID/
#   WEBAPI_CLIENT_SECRET are set (see e2e/_Setup.ps1 for the full env-var list).
#   $script:E2EEnabled must be computed at dot-source time (DISCOVERY phase) so
#   `Describe -Skip:(...)` binds correctly — do not move this below the Describe.
#
# Prerequisites:
#   - Manager credential with access to a connected, pumping trade platform.
#   - An active price feed on the chosen symbol (default EURUSD, override via
#     WEBAPI_SYMBOL) for the tick test. Closed market / no feed -> the tick
#     test times out. Extend WEBAPI_E2E_TICK_TIMEOUT_MS (default 20000 ms) if
#     the feed is slow.
#
# Run:  WEBAPI_E2E=1 pwsh -NoProfile -Command "Invoke-Pester ./e2e -Output Detailed"

. "$PSScriptRoot/_Setup.ps1"

Describe 'SignalR e2e (staging)' -Skip:(-not $script:E2EEnabled) {
    BeforeAll {
        # * Re-dot-source in the Run phase (Discovery-phase top-level dot-source
        #   only set the -Skip gate; the helper functions must be defined here too).
        . "$PSScriptRoot/_Setup.ps1"
        Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
        Connect-E2E
        $script:Tp = Resolve-E2ETradePlatform
        Write-Verbose "[E2E SignalR] trade platform: $script:Tp symbol: $script:E2ESymbol" -Verbose
    }

    # -------------------------------------------------------------------------
    # * Connection lifecycle — Connect-MT4Realtime succeeds and the server
    #   pushes OnConnectionStatus immediately after the handshake.
    # -------------------------------------------------------------------------
    It 'Connect-MT4Realtime receives OnConnectionStatus within 5s' {
        $rt = Connect-MT4Realtime -TradePlatform $script:Tp
        try {
            $msg = Receive-MT4Realtime -Connection $rt -TimeoutSeconds 5 |
                Where-Object { $_.Method -eq 'OnConnectionStatus' } |
                Select-Object -First 1
            $msg | Should -Not -BeNullOrEmpty
        } finally {
            Disconnect-MT4Realtime -Connection $rt
        }
    }

    # -------------------------------------------------------------------------
    # * Tick streaming — first tick arrives within $script:E2ETickTimeoutSec.
    #
    #   ! This test requires an active price feed. On a closed market or a
    #     platform without live prices it will time out — see the module notes
    #     above for WEBAPI_E2E_TICK_TIMEOUT_MS.
    # -------------------------------------------------------------------------
    It 'Register-MT4Realtime Ticks receives a tick with symbol/bid/ask' {
        $rt = Connect-MT4Realtime -TradePlatform $script:Tp
        try {
            Register-MT4Realtime -Connection $rt -Category Ticks -Symbol $script:E2ESymbol
            $tick = Receive-MT4Realtime -Connection $rt -TimeoutSeconds $script:E2ETickTimeoutSec |
                Where-Object { $_.Method -eq 'OnTick' } |
                Select-Object -First 1

            $tick | Should -Not -BeNullOrEmpty
            $tick.Payload.symbol | Should -Be $script:E2ESymbol
            [double]$tick.Payload.bid | Should -BeGreaterThan 0
            [double]$tick.Payload.ask | Should -BeGreaterThan 0
        } finally {
            Disconnect-MT4Realtime -Connection $rt
        }
    }

    AfterAll {
        if ($script:E2EEnabled) { Disconnect-MyWebApi }
    }
}
