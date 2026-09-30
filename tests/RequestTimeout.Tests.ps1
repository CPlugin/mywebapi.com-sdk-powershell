BeforeAll {
    Import-Module "$PSScriptRoot/../src/MyWebApi/MyWebApi.psd1" -Force
}

Describe 'Request timeouts' {
    BeforeEach {
        InModuleScope MyWebApi {
            $script:MyWebApiContext = @{
                BaseUrl = 'https://api.example'; AccessToken = 'tok'; ExpiresAt = [DateTimeOffset]::UtcNow.AddHours(1)
                ClientId = $null; DefaultTradePlatform = 'demo'; MaxGetRetries = 2; HttpTimeoutSeconds = 30
            }
        }
    }

    Context 'X-Request-Timeout header' {
        It 'sends -RequestTimeout with invariant-culture formatting' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
                $culture = [System.Globalization.CultureInfo]::CurrentCulture
                try {
                    [System.Globalization.CultureInfo]::CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
                    Get-MT4UserRecordGet -Login 42 -RequestTimeout 2.5 | Out-Null
                } finally {
                    [System.Globalization.CultureInfo]::CurrentCulture = $culture
                }
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $Headers['X-Request-Timeout'] -eq '2.5' }
            }
        }

        It 'sends no header when neither the cmdlet nor the session sets a timeout' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
                Get-MT4UserRecordGet -Login 42 | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { -not $Headers.ContainsKey('X-Request-Timeout') }
            }
        }

        It 'uses the session default, and the cmdlet parameter wins over it' {
            InModuleScope MyWebApi {
                $script:MyWebApiContext.RequestTimeout = 12
                Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
                Get-MT4UserRecordGet -Login 42 | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $Headers['X-Request-Timeout'] -eq '12' }
                Get-MT4UserRecordGet -Login 42 -RequestTimeout 3 | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $Headers['X-Request-Timeout'] -eq '3' }
            }
        }

        It 'stores the session default from Connect-MyWebApi' {
            InModuleScope MyWebApi {
                $c = Connect-MyWebApi -BaseUrl 'https://api.example' -AccessToken 't' -RequestTimeout 20
                $c.RequestTimeout | Should -Be 20
                (Connect-MyWebApi -BaseUrl 'https://api.example' -AccessToken 't').RequestTimeout | Should -BeNullOrEmpty
            }
        }
    }

    Context 'validation' {
        It 'rejects <Value> on a generated cmdlet before any request' -ForEach @(@{ Value = 0 }, @{ Value = 0.5 }, @{ Value = 301 }) {
            InModuleScope MyWebApi -Parameters @{ Value = $Value } {
                param($Value)
                Mock Invoke-MyWebApiHttpJson {}
                { Get-MT4UserRecordGet -Login 42 -RequestTimeout $Value } | Should -Throw -ErrorId 'ParameterArgumentValidationError*'
                Should -Invoke Invoke-MyWebApiHttpJson -Times 0
            }
        }

        It 'rejects an out-of-range session default on Connect-MyWebApi' {
            { Connect-MyWebApi -BaseUrl 'https://api.example' -AccessToken 't' -RequestTimeout 301 } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError*'
        }

        It 'rejects a malformed session default set on a hand-built connection' {
            InModuleScope MyWebApi {
                $script:MyWebApiContext.RequestTimeout = 'soon'
                Mock Invoke-MyWebApiHttpJson {}
                { Get-MT4UserRecordGet -Login 42 } | Should -Throw -ExpectedMessage '*RequestTimeout must be a number of seconds from 1 to 300*'
            }
        }

        It 'surfaces the server''s Validation error for a rejected timeout' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith {
                    [pscustomobject]@{ error = [pscustomobject]@{ code = 'Validation'; message = 'X-Request-Timeout / requestTimeout must be a number of seconds from 1 to 300' } }
                }
                $e = { Get-MT4UserRecordGet -Login 42 -RequestTimeout 300 } | Should -Throw -PassThru
                $e.FullyQualifiedErrorId | Should -BeLike 'MyWebApiError,Validation*'
                $e.TargetObject.Retryable | Should -BeFalse
            }
        }
    }

    Context 'HTTP deadline' {
        It 'keeps the HTTP deadline 30 s beyond the requested server timeout' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
                Get-MT4UserRecordGet -Login 42 -RequestTimeout 120 | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $TimeoutSeconds -eq 150 }
            }
        }

        It 'sizes the deadline from the operation''s documented default when no timeout is requested' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
                # Trade operation: server default 5 s, so the session's 30 s HTTP deadline is already enough.
                Invoke-MT4TradeTransaction -Body @{ } -Confirm:$false | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $TimeoutSeconds -eq 35 }
            }
        }

        It 'keeps an explicitly chosen HttpTimeoutSeconds as a hard cap when no timeout is requested' {
            InModuleScope MyWebApi {
                $script:MyWebApiContext.HttpTimeoutSeconds = 3
                $script:MyWebApiContext.HttpTimeoutExplicit = $true
                Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
                Get-MT4TradesUserHistory -Login 42 | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $TimeoutSeconds -eq 3 }
                Get-MT4TradesUserHistory -Login 42 -RequestTimeout 10 | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $TimeoutSeconds -eq 40 }
            }
        }

        It 'never goes below the session HttpTimeoutSeconds' {
            InModuleScope MyWebApi {
                $script:MyWebApiContext.HttpTimeoutSeconds = 200
                Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
                Get-MT4UserRecordGet -Login 42 -RequestTimeout 1 | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $TimeoutSeconds -eq 200 }
            }
        }

        It 'handles a sidecar operation like the rest: one -RequestTimeout, the header, its documented default' {
            InModuleScope MyWebApi {
                $params = (Get-Command Get-MT4TradesSnapshot).Parameters.Keys
                @($params | Where-Object { $_ -match 'Timeout' } | Sort-Object) | Should -Be @('CacheTimeout', 'RequestTimeout')
                Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
                # History operation: server default 30 s, so the HTTP deadline is 60 s, not the 90 s assumed for an undocumented one.
                Get-MT4TradesSnapshot | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $TimeoutSeconds -eq 60 -and -not $Headers.ContainsKey('X-Request-Timeout') }
                Get-MT4TradesSnapshot -RequestTimeout 7 | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $Headers['X-Request-Timeout'] -eq '7' -and $TimeoutSeconds -eq 37 }
            }
        }

        It 'assumes the longest server default for an operation without a documented one' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith { [pscustomobject]@{ data = 1 } }
                Invoke-MyWebApiRequest -Method Get -Path '/api/v2/MT4/{tradePlatform}/Undocumented' | Out-Null
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1 -ParameterFilter { $TimeoutSeconds -eq 90 }
            }
        }
    }

    Context 'error outcome' {
        It 'reports OutcomeUnknown with the outcome header, guidance and no retry' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith {
                    $ResponseHeaders['X-Request-Outcome'] = 'unknown'
                    $ResponseHeaders['X-Request-Timeout-Applied'] = '5'
                    [pscustomobject]@{
                        error = [pscustomobject]@{ code = 'OutcomeUnknown'; message = 'The trade server did not answer in time' }
                        meta  = [pscustomobject]@{ activityId = 'act-1' }
                    }
                }
                $e = { Invoke-MT4TradeTransaction -Body @{ } -IdempotencyKey 'k-1' -Confirm:$false } | Should -Throw -PassThru
                $e.FullyQualifiedErrorId | Should -BeLike 'MyWebApiError,OutcomeUnknown*'
                $e.CategoryInfo.Category | Should -Be 'OperationTimeout'
                $e.TargetObject.Code | Should -Be 'OutcomeUnknown'
                $e.TargetObject.Outcome | Should -Be 'unknown'
                $e.TargetObject.RequestTimeoutApplied | Should -Be '5'
                $e.TargetObject.Retryable | Should -BeFalse
                $e.TargetObject.IdempotencyKey | Should -Be 'k-1'
                $e.TargetObject.ActivityId | Should -Be 'act-1'
                $e.Exception.Data['Outcome'] | Should -Be 'unknown'
                $e.Exception.Message | Should -BeLike '*outcome=unknown*same -IdempotencyKey*'
                $e.ErrorDetails.RecommendedAction | Should -BeLike 'The operation did not finish in time*'
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1
            }
        }

        It 'explains an in-progress idempotent repeat' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith {
                    $ResponseHeaders['X-Request-Outcome'] = 'in-progress'
                    [pscustomobject]@{ error = [pscustomobject]@{ code = 'OutcomeUnknown'; message = 'still processing' } }
                }
                $e = { Invoke-MT4TradeTransaction -Body @{ } -IdempotencyKey 'k-2' -Confirm:$false } | Should -Throw -PassThru
                $e.TargetObject.Outcome | Should -Be 'in-progress'
                $e.ErrorDetails.RecommendedAction | Should -BeLike '*still being processed*same -IdempotencyKey*'
            }
        }

        It 'marks a read Timeout as safe to repeat but does not retry it automatically' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith {
                    $ResponseHeaders['X-Request-Outcome'] = 'timeout'
                    [pscustomobject]@{ error = [pscustomobject]@{ code = 'Timeout'; message = 'slow' } }
                }
                $e = { Get-MT4UserRecordGet -Login 42 } | Should -Throw -PassThru
                $e.FullyQualifiedErrorId | Should -BeLike 'MyWebApiError,Timeout*'
                $e.TargetObject.Retryable | Should -BeTrue
                $e.ErrorDetails.RecommendedAction | Should -BeLike '*safe to repeat*-RequestTimeout*'
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1
            }
        }

        It 'retries a Busy GET within MaxGetRetries' {
            InModuleScope MyWebApi {
                $script:calls = 0
                Mock Invoke-MyWebApiHttpJson -MockWith {
                    $script:calls++
                    if ($script:calls -lt 3) {
                        $ResponseHeaders['X-Request-Outcome'] = 'not-started'
                        [pscustomobject]@{ error = [pscustomobject]@{ code = 'Busy'; message = 'busy' } }
                    } else {
                        [pscustomobject]@{ data = [pscustomobject]@{ login = 42 } }
                    }
                }
                (Get-MT4UserRecordGet -Login 42).login | Should -Be 42
                Should -Invoke Invoke-MyWebApiHttpJson -Times 3
            }
        }

        It 'reports Busy as retryable once GET retries are exhausted' {
            InModuleScope MyWebApi {
                $script:MyWebApiContext.MaxGetRetries = 0
                Mock Invoke-MyWebApiHttpJson -MockWith {
                    $ResponseHeaders['X-Request-Outcome'] = 'not-started'
                    [pscustomobject]@{ error = [pscustomobject]@{ code = 'Busy'; message = 'busy' } }
                }
                $e = { Get-MT4UserRecordGet -Login 42 } | Should -Throw -PassThru
                $e.CategoryInfo.Category | Should -Be 'ResourceBusy'
                $e.TargetObject.Outcome | Should -Be 'not-started'
                $e.TargetObject.Retryable | Should -BeTrue
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1
            }
        }
    }

    Context 'writes are never retried' {
        It 'sends a Busy write once' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith {
                    [pscustomobject]@{ error = [pscustomobject]@{ code = 'Busy'; message = 'busy' } }
                }
                { Invoke-MT4TradeTransaction -Body @{ } -IdempotencyKey 'k-3' -Confirm:$false } | Should -Throw -ErrorId 'MyWebApiError,Busy*'
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1
            }
        }

        It 'sends a write once after a transport failure, even with an Idempotency-Key' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith {
                    $err = [System.Net.Http.HttpRequestException]::new('HTTP 503')
                    $err.Data['StatusCode'] = 503
                    throw $err
                }
                { Invoke-MT4TradeTransaction -Body @{ } -IdempotencyKey 'k-4' -Confirm:$false } | Should -Throw '*HTTP 503*'
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1
            }
        }

        It 'reports a client-side HTTP deadline on a write as an unknown outcome, once' {
            InModuleScope MyWebApi {
                Mock Invoke-MyWebApiHttpJson -MockWith { throw [System.TimeoutException]::new('deadline') }
                $e = { Invoke-MT4TradeTransaction -Body @{ } -Confirm:$false } | Should -Throw -PassThru
                $e.FullyQualifiedErrorId | Should -BeLike 'MyWebApiHttpTimeout*'
                $e.TargetObject.Source | Should -Be 'client'
                $e.TargetObject.Outcome | Should -Be 'unknown'
                $e.TargetObject.Retryable | Should -BeFalse
                $e.ErrorDetails.RecommendedAction | Should -BeLike '*Pass -IdempotencyKey*'
                Should -Invoke Invoke-MyWebApiHttpJson -Times 1
            }
        }

        It 'retries a GET after a client-side HTTP deadline' {
            InModuleScope MyWebApi {
                $script:calls = 0
                Mock Invoke-MyWebApiHttpJson -MockWith {
                    $script:calls++
                    if ($script:calls -eq 1) { throw [System.TimeoutException]::new('deadline') }
                    [pscustomobject]@{ data = 7 }
                }
                Get-MT4UserRecordGet -Login 42 | Should -Be 7
                Should -Invoke Invoke-MyWebApiHttpJson -Times 2
            }
        }
    }
}

Describe 'Invoke-MyWebApiHttpJson response headers' {
    It 'captures response headers and honours -TimeoutSeconds against a loopback server' {
        InModuleScope MyWebApi {
            $listener = [System.Net.HttpListener]::new()
            $port = Get-Random -Minimum 20000 -Maximum 60000
            $prefix = "http://127.0.0.1:$port/"
            $listener.Prefixes.Add($prefix)
            $listener.Start()
            try {
                $job = Start-ThreadJob -ArgumentList $listener -ScriptBlock {
                    param($l)
                    $ctx = $l.GetContext()
                    $ctx.Response.Headers.Add('X-Request-Outcome', 'unknown')
                    $ctx.Response.Headers.Add('X-Request-Timeout-Applied', $ctx.Request.Headers['X-Request-Timeout'])
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":{"code":"OutcomeUnknown","message":"late"}}')
                    $ctx.Response.ContentType = 'application/json'
                    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                    $ctx.Response.Close()
                }
                $context = @{ BaseUrl = $prefix; AllowInsecureLoopback = $true; HttpTimeoutSeconds = 30 }
                $headers = @{}
                $resp = Invoke-MyWebApiHttpJson -Context $context -Method Post -Uri "${prefix}x" -Headers @{ 'X-Request-Timeout' = '7' } -TimeoutSeconds 10 -ResponseHeaders $headers
                $resp.error.code | Should -Be 'OutcomeUnknown'
                $headers['X-Request-Outcome'] | Should -Be 'unknown'
                $headers['x-request-timeout-applied'] | Should -Be '7'
                $job | Wait-Job -Timeout 10 | Out-Null
            } finally {
                $listener.Stop()
                $listener.Close()
                if ($job) { $job | Remove-Job -Force }
            }
        }
    }
}
