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
    It 'imports with no unapproved-verb warnings beyond the documented Subscribe exception' {
        # 'Subscribe' is not in Get-Verb's approved list, but it is the deliberate, user-confirmed
        # verb for the realtime pub/sub cmdlets (Subscribe-MT4Realtime / Subscribe-MT5Realtime) --
        # it mirrors the SignalR hub terminology the SDK wraps and reads far more clearly to SDK
        # consumers than the nominal PowerShell alternative ('Register', which PowerShell reserves
        # for event/ObjectEvent subscriptions, a different concept). This test still fails on any
        # OTHER unapproved verb, so a real mistake elsewhere is still caught.
        $approvedVerbs = (Get-Verb).Verb
        $allowedExceptions = @('Subscribe')
        $commands = Get-Command -Module MyWebApi
        $offending = $commands | Where-Object {
            $verb = ($_.Name -split '-', 2)[0]
            $verb -notin $approvedVerbs -and $verb -notin $allowedExceptions
        }
        $offending | Should -BeNullOrEmpty
    }
}
