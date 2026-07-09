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
