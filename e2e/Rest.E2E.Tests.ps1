BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
    $script:HasCreds = $env:WEBAPI_E2E -eq '1' -and $env:WEBAPI_CLIENT_ID -and $env:WEBAPI_CLIENT_SECRET
    if ($script:HasCreds) {
        $envName = if ($env:WEBAPI_ENV) { $env:WEBAPI_ENV } else { 'Staging' }
        $sec = ConvertTo-SecureString $env:WEBAPI_CLIENT_SECRET -AsPlainText -Force
        Connect-MyWebApi -Environment $envName -ClientId $env:WEBAPI_CLIENT_ID -ClientSecret $sec
        $script:Tp = if ($env:WEBAPI_TRADE_PLATFORM) { $env:WEBAPI_TRADE_PLATFORM } else { (Get-MyWebApiTradePlatform)[0].id }
    }
}

Describe 'REST e2e (staging)' -Skip:(-not $script:HasCreds) {
    It 'discovers at least one trade platform' {
        (Get-MyWebApiTradePlatform) | Should -Not -BeNullOrEmpty
    }
    It 'reads server time' {
        $t = Get-MT4ServerTime -TradePlatform $script:Tp
        $t | Should -Not -BeNullOrEmpty
    }
    It 'lists users with paging' {
        $users = Get-MT4UsersRequest -TradePlatform $script:Tp -All
        $users | Should -Not -BeNullOrEmpty
    }
}

AfterAll {
    if ($script:HasCreds) { Disconnect-MyWebApi }
}
