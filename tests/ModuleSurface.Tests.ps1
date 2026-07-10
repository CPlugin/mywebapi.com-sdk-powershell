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
        $approvedVerbs = (Get-Verb).Verb
        $commands = Get-Command -Module MyWebApi
        $offending = $commands | Where-Object {
            $verb = ($_.Name -split '-', 2)[0]
            $verb -notin $approvedVerbs
        }
        $offending | Should -BeNullOrEmpty
    }
}
