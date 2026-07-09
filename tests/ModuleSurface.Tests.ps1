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
