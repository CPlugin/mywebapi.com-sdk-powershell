BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}

Describe 'PATCH cmdlets (JSON Merge Patch body)' {
    BeforeEach {
        InModuleScope MyWebApi {
            $script:MyWebApiContext = @{
                BaseUrl = 'https://api.example'; AccessToken = 'tok'; ExpiresAt = [DateTimeOffset]::UtcNow.AddHours(1)
                ClientId = $null; DefaultTradePlatform = 'demo'
            }
        }
    }

    It 'sends a hashtable patch as a PATCH with that object as the JSON body' {
        InModuleScope MyWebApi {
            Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = [pscustomobject]@{ login = 42 } } }
            Update-MT4UserRecord -Login 42 -Body @{ leverage = 200 } -Confirm:$false | Out-Null
            Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter {
                $Method -eq 'Patch' -and $Uri -like '*/api/v2/MT4/demo/UserRecord/42' -and
                ($JsonBody | ConvertTo-Json -Compress) -eq '{"leverage":200}'
            }
        }
    }

    It 'accepts a [pscustomobject] patch on an MT5 cmdlet' {
        InModuleScope MyWebApi {
            Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
            Update-MT5UserRecord -Login 7 -Body ([pscustomobject]@{ name = 'n' }) -Confirm:$false | Out-Null
            Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $JsonBody.name -eq 'n' }
        }
    }

    It 'refuses a <Name> patch before any request' -ForEach @(
        @{ Name = 'scalar'; Value = 'leverage=200' }
        @{ Name = 'array'; Value = @(1, 2) }
    ) {
        InModuleScope MyWebApi -Parameters @{ Value = $Value } {
            param($Value)
            Mock Invoke-MyWebApiHttpJson {}
            { Update-MT4UserRecord -Login 42 -Body $Value -Confirm:$false } | Should -Throw -ExpectedMessage '*Body must be a hashtable or `[pscustomobject`]*'
            Should -Invoke Invoke-MyWebApiHttpJson -Times 0
        }
    }

    It 'makes -Body mandatory on every PATCH cmdlet and on ExternalCommandJSON' {
        $names = @('Update-MT4GroupRecord', 'Update-MT4SymbolConfig', 'Update-MT4UserRecord',
                   'Update-MT5GroupRecord', 'Update-MT5SymbolRecord', 'Update-MT5UserRecord', 'Invoke-MT4ExternalCommandJSON')
        foreach ($n in $names) {
            $p = (Get-Command $n).Parameters['Body']
            $p.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Contain $true -Because $n
        }
    }

    It 'keeps -Body optional where the spec does not require one' {
        $p = (Get-Command Invoke-MT4TradeTransaction).Parameters['Body']
        $p.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Not -Contain $true
    }
}
