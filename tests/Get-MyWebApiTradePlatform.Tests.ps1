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
