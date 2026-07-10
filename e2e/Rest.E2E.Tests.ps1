# * E2E tests for the REST surface of the MyWebApi v2 SDK.
#
# These tests exercise the REAL running WebAPI server end-to-end: OAuth token
# acquisition -> HTTPS call -> v2 envelope unwrap.
#
# ! GATED — every test skips unless WEBAPI_E2E=1 AND WEBAPI_CLIENT_ID/
#   WEBAPI_CLIENT_SECRET are set (see e2e/_Setup.ps1 for the full env-var list).
#   $script:E2EEnabled must be computed at dot-source time (DISCOVERY phase) so
#   `Describe -Skip:(...)` binds correctly — do not move this below the Describe.
#
# Prerequisites:
#   - Manager credential (client_id/client_secret with MANAGER rights on a
#     connected trade platform). A user-only credential gets HTTP 403 on
#     ServerTime and CfgRequestCommon, which will fail those tests.
#   - At least one trade platform connected and pumping.
#
# Run:  WEBAPI_E2E=1 pwsh -NoProfile -Command "Invoke-Pester ./e2e -Output Detailed"

. "$PSScriptRoot/_Setup.ps1"

Describe 'REST e2e (staging)' -Skip:(-not $script:E2EEnabled) {
    BeforeAll {
        # * Re-dot-source in the Run phase: the top-level dot-source ran during
        #   Discovery (for the -Skip gate), but Connect-E2E/Resolve-E2ETradePlatform
        #   must also be defined in the Run scope where BeforeAll/It execute.
        . "$PSScriptRoot/_Setup.ps1"
        Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
        Connect-E2E
        $script:Tp = Resolve-E2ETradePlatform
        Write-Verbose "[E2E REST] trade platform: $script:Tp" -Verbose
    }

    # -------------------------------------------------------------------------
    # * Get-MyWebApiTradePlatform — basic connectivity + auth sanity
    # -------------------------------------------------------------------------
    It 'Get-MyWebApiTradePlatform returns a non-empty array with string ids' {
        $platforms = @(Get-MyWebApiTradePlatform)
        $platforms.Count | Should -BeGreaterThan 0
        foreach ($p in $platforms) {
            $p.id | Should -BeOfType [string]
            $p.id.Length | Should -BeGreaterThan 0
        }
    }

    # -------------------------------------------------------------------------
    # * Get-MT4ServerTime — proves OAuth token + manager call + envelope unwrap
    # -------------------------------------------------------------------------
    It 'Get-MT4ServerTime returns a date within +/-1 day of now' {
        $t = Get-MT4ServerTime -TradePlatform $script:Tp
        $t | Should -Not -BeNullOrEmpty

        $parsed = [datetime]$t
        $delta = [Math]::Abs(([datetime]::UtcNow - $parsed.ToUniversalTime()).TotalDays)
        $delta | Should -BeLessThan 1
    }

    # -------------------------------------------------------------------------
    # * Get-MT4CfgRequestCommon — manager-level config read
    # -------------------------------------------------------------------------
    It 'Get-MT4CfgRequestCommon returns a non-null object' {
        $cfg = Get-MT4CfgRequestCommon -TradePlatform $script:Tp
        $cfg | Should -Not -BeNullOrEmpty
    }

    # -------------------------------------------------------------------------
    # * Get-MT4TradesGet -All — pagination helper (cursor loop terminates cleanly)
    # -------------------------------------------------------------------------
    It 'Get-MT4TradesGet -All completes; items (if any) are objects' {
        $trades = @(Get-MT4TradesGet -TradePlatform $script:Tp -All)
        foreach ($trade in $trades) {
            $trade | Should -Not -BeNullOrEmpty
        }
    }

    # -------------------------------------------------------------------------
    # * Get-MT4UserRecordGet with a nonexistent login — terminating-error path
    #
    #   Invoke-MyWebApiRequest throws a terminating error whose FullyQualifiedErrorId
    #   is "MyWebApiError,<code>" and whose message embeds "activityId=<traceId>"
    #   (the W3C trace id from ApiMeta) when the server returns a v2 error envelope.
    # -------------------------------------------------------------------------
    It 'Get-MT4UserRecordGet with bogus login throws with an error code and activityId' {
        $e = { Get-MT4UserRecordGet -TradePlatform $script:Tp -Login 999999999 } | Should -Throw -PassThru
        $e.FullyQualifiedErrorId | Should -BeLike '*MyWebApiError,*'
        $e.Exception.Message | Should -Match 'activityId='
    }

    AfterAll {
        if ($script:E2EEnabled) { Disconnect-MyWebApi }
    }
}
