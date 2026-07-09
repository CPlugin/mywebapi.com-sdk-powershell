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
