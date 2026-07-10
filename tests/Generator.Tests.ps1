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
    It 'emits Limit/Cursor/All on a cursor-paged endpoint' {
        $content = Get-Content "$pub/MT4/Get-MT4UsersRequest.ps1" -Raw
        $content | Should -Match '\$Limit\b'
        $content | Should -Match '\$Cursor\b'
        $content | Should -Match '\[switch\] \$All\b'
    }
    It 'emits a Shift parameter on a shift op' {
        Get-Content "$pub/MT4/Invoke-MT4CfgShiftAccess.ps1" -Raw | Should -Match '\[int\] \$Shift\b'
    }
    It 'emits an int[] parameter for an array query param (logins)' {
        Get-Content "$pub/MT4/Get-MT4UserRecordsRequest.ps1" -Raw | Should -Match '\[int\[\]\] \$Logins\b'
    }
    It 'suffixes a reserved-name query param (confirm) with Query to avoid colliding with -Confirm' {
        Get-Content "$pub/MT4/Invoke-MT4SrvRestart.ps1" -Raw | Should -Match '\[switch\] \$ConfirmQuery\b'
    }
}
