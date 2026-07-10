BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}

Describe 'Invoke-MyWebApiRequest' {
    BeforeEach {
        InModuleScope MyWebApi {
            $script:MyWebApiContext = @{
                BaseUrl = 'https://api.example'; AccessToken = 'tok'; ExpiresAt = [DateTimeOffset]::UtcNow.AddHours(1)
                ClientId = $null; DefaultTradePlatform = 'demo'
            }
        }
    }

    It 'unwraps .data on success and sends the bearer token' {
        InModuleScope MyWebApi {
            Mock Invoke-RestMethod -MockWith {
                [pscustomobject]@{ data = [pscustomobject]@{ login = 42 }; error = $null; meta = $null }
            }
            $r = Invoke-MyWebApiRequest -Method Get -Path '/api/v2/MT4/{tradePlatform}/UserRecordGet/42'
            $r.login | Should -Be 42
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Headers.Authorization -eq 'Bearer tok' -and $Uri -like 'https://api.example/*'
            }
        }
    }

    It 'throws a terminating error carrying the envelope message' {
        InModuleScope MyWebApi {
            Mock Invoke-RestMethod -MockWith {
                [pscustomobject]@{
                    data = $null
                    error = [pscustomobject]@{ code = 'NotFound'; message = 'no such user'; managerCode = $null }
                    meta = [pscustomobject]@{ activityId = 'abc-123' }
                }
            }
            $e = { Invoke-MyWebApiRequest -Method Get -Path '/x' } | Should -Throw -ExpectedMessage '*no such user*' -PassThru
            $e.FullyQualifiedErrorId | Should -BeLike '*MyWebApiError,NotFound*'
        }
    }

    It 'encodes an array query value as repeated keys' {
        InModuleScope MyWebApi {
            Mock Invoke-RestMethod -MockWith {
                [pscustomobject]@{ data = @(); error = $null; meta = $null }
            }
            Invoke-MyWebApiRequest -Method Get -Path '/list' -Query @{ logins = @(1, 2) } | Out-Null
            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -like '*logins=1&logins=2*'
            }
        }
    }

    It 'follows cursor paging when -All is set' {
        InModuleScope MyWebApi {
            $script:calls = 0
            Mock Invoke-RestMethod -MockWith {
                $script:calls++
                if ($script:calls -eq 1) {
                    [pscustomobject]@{ data = @(1,2); error = $null; meta = [pscustomobject]@{ paging = [pscustomobject]@{ nextCursor = 'c2'; hasMore = $true } } }
                } else {
                    [pscustomobject]@{ data = @(3);   error = $null; meta = [pscustomobject]@{ paging = [pscustomobject]@{ nextCursor = $null; hasMore = $false } } }
                }
            }
            $items = Invoke-MyWebApiRequest -Method Get -Path '/list' -All
            $items | Should -Be @(1,2,3)
            Should -Invoke Invoke-RestMethod -Times 2
        }
    }
}
