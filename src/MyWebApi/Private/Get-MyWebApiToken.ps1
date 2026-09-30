function Get-MyWebApiToken {
    # Returns a valid bearer token, refreshing via client_credentials if expired.
    # RefreshGate is per connection: concurrent callers for one target single-flight,
    # while independent targets never share credentials or refresh state.
    [CmdletBinding()]
    param([object] $Connection)

    $ctx = Resolve-MyWebApiContext -Connection $Connection
    if ([bool](Get-MyWebApiContextProperty -Context $ctx -Name 'Disposed')) {
        throw 'The supplied MyWebApi connection has been disconnected.'
    }

    $get = { param([string]$name) Get-MyWebApiContextProperty -Context $ctx -Name $name }
    $token = & $get 'AccessToken'
    $expiresAt = & $get 'ExpiresAt'
    if ($token -and $expiresAt -and ($expiresAt -gt [DateTimeOffset]::UtcNow.AddSeconds(30))) {
        return $token
    }
    if (-not (& $get 'ClientId')) {
        # A pre-obtained token has no refresh credentials. Let the server report expiry.
        return $token
    }

    $gate = & $get 'RefreshGate'
    if ($null -eq $gate) {
        $gate = [System.Threading.SemaphoreSlim]::new(1, 1)
        Set-MyWebApiContextProperty -Context $ctx -Name 'RefreshGate' -Value $gate
    }
    $timeout = Get-MyWebApiTimeoutSeconds -Context $ctx
    $entered = $false
    try {
        if (-not $gate.Wait($timeout * 1000)) {
            throw "Timed out waiting for OAuth token refresh after $timeout second(s)."
        }
        $entered = $true

        # Another caller may have refreshed while this caller waited.
        $token = & $get 'AccessToken'
        $expiresAt = & $get 'ExpiresAt'
        if ($token -and $expiresAt -and ($expiresAt -gt [DateTimeOffset]::UtcNow.AddSeconds(30))) {
            return $token
        }

        $authority = & $get 'Authority'
        if (-not $authority) { throw 'Authority is required for token refresh.' }
        $authorityUri = Assert-MyWebApiEndpoint -Value $authority -Name 'Authority' -Context $ctx
        $discoveryUri = '{0}/.well-known/openid-configuration' -f $authorityUri.AbsoluteUri.TrimEnd('/')
        Assert-MyWebApiNotCancelled -Context $ctx
        $discovery = Invoke-MyWebApiHttpJson -Context $ctx -Method Get -Uri $discoveryUri
        $tokenEndpointValue = Get-MyWebApiContextProperty -Context $discovery -Name 'token_endpoint'
        if (-not $tokenEndpointValue) { throw 'OAuth discovery did not return token_endpoint.' }
        $tokenEndpoint = Assert-MyWebApiEndpoint -Value ([string]$tokenEndpointValue) -Name 'token_endpoint' -Context $ctx

        $authorityOrigin = Get-MyWebApiOrigin -Uri $authorityUri
        $trustedValue = & $get 'TrustedTokenEndpoint'
        $trustedUri = $null
        if ($trustedValue) {
            $trustedUri = Assert-MyWebApiEndpoint -Value ([string]$trustedValue) -Name 'TrustedTokenEndpoint' -Context $ctx
        }
        $sameOrigin = [string]::Equals((Get-MyWebApiOrigin -Uri $tokenEndpoint), $authorityOrigin, [StringComparison]::OrdinalIgnoreCase)
        $explicitTrust = $trustedUri -and [string]::Equals($tokenEndpoint.AbsoluteUri.TrimEnd('/'), $trustedUri.AbsoluteUri.TrimEnd('/'), [StringComparison]::OrdinalIgnoreCase)
        if (-not $sameOrigin -and -not $explicitTrust) {
            throw 'OAuth discovery returned a token_endpoint outside Authority; configure an exact TrustedTokenEndpoint to opt in.'
        }

        $bstr = [IntPtr]::Zero
        $plainSecret = $null
        try {
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((& $get 'ClientSecret'))
            $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            $body = @{
                grant_type    = 'client_credentials'
                client_id     = (& $get 'ClientId')
                client_secret = $plainSecret
                scope         = (& $get 'Scope')
            }
            Assert-MyWebApiNotCancelled -Context $ctx
            $response = Invoke-MyWebApiHttpJson -Context $ctx -Method Post -Uri $tokenEndpoint.AbsoluteUri -FormBody $body
        }
        finally {
            if ($bstr -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
            $plainSecret = $null
        }

        $newToken = Get-MyWebApiContextProperty -Context $response -Name 'access_token'
        if (-not $newToken) { throw 'OAuth token response did not contain access_token.' }
        $expiresIn = Get-MyWebApiContextProperty -Context $response -Name 'expires_in'
        if ($null -eq $expiresIn -or [int]$expiresIn -lt 1) { $expiresIn = 300 }
        Set-MyWebApiContextProperty -Context $ctx -Name 'AccessToken' -Value ([string]$newToken)
        Set-MyWebApiContextProperty -Context $ctx -Name 'ExpiresAt' -Value ([DateTimeOffset]::UtcNow.AddSeconds([int]$expiresIn))
        return [string]$newToken
    }
    finally {
        if ($entered) { [void]$gate.Release() }
    }
}
