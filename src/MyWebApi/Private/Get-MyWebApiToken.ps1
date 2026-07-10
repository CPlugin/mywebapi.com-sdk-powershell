function Get-MyWebApiToken {
    # Returns a valid bearer token, refreshing via client_credentials if expired.
    [CmdletBinding()]
    param()

    if (-not $script:MyWebApiContext) {
        throw 'Not connected. Call Connect-MyWebApi first.'
    }

    $ctx = $script:MyWebApiContext
    $stillValid = $ctx.AccessToken -and $ctx.ExpiresAt -and
                  ($ctx.ExpiresAt -gt [DateTimeOffset]::UtcNow.AddSeconds(30))
    if ($stillValid) { return $ctx.AccessToken }

    if (-not $ctx.ClientId) {
        # Pre-set token with no refresh credentials -- return as-is (may be expired; server will 401).
        return $ctx.AccessToken
    }

    # Refresh: discover the token endpoint, then request a client_credentials token.
    $disco = Invoke-RestMethod -Method Get -Uri ("{0}/.well-known/openid-configuration" -f $ctx.Authority.TrimEnd('/'))
    $tokenEndpoint = $disco.token_endpoint

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ctx.ClientSecret)
    try {
        $plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $body = @{
            grant_type    = 'client_credentials'
            client_id     = $ctx.ClientId
            client_secret = $plainSecret
            scope         = $ctx.Scope
        }
        $resp = Invoke-RestMethod -Method Post -Uri $tokenEndpoint -Body $body `
            -ContentType 'application/x-www-form-urlencoded'
    }
    finally {
        # Free the unmanaged BSTR buffer (zeroed) and drop the managed plaintext reference.
        if ($bstr -ne [IntPtr]::Zero) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
        $plainSecret = $null
    }

    $ctx.AccessToken = $resp.access_token
    $ctx.ExpiresAt   = [DateTimeOffset]::UtcNow.AddSeconds([int]$resp.expires_in)
    return $ctx.AccessToken
}
