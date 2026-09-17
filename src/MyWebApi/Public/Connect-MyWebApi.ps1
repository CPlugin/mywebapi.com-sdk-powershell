function Connect-MyWebApi {
    <#
    .SYNOPSIS
        Creates an isolated WebAPI v2 session and makes it the optional default connection.
    .DESCRIPTION
        Returns a connection object. Pass that object to generated cmdlets with -Connection
        when more than one target is used; omitting -Connection retains the single-session
        convenience API. OAuth discovery is same-origin by default and all endpoints require
        HTTPS, except an explicit loopback-only HTTP opt-in for tests.
    #>
    [CmdletBinding()]
    param(
        [Parameter()][ValidateSet('Staging','Production')][string] $Environment,
        [Parameter()][string] $BaseUrl,
        [Parameter()][string] $Authority,
        [Parameter()][string] $ClientId,
        [Parameter()][SecureString] $ClientSecret,
        [Parameter()][string] $AccessToken,
        [Parameter()][string] $Scope = 'webapi',
        [Parameter()][string] $DefaultTradePlatform,
        [Parameter()][string] $TrustedTokenEndpoint,
        [Parameter()][switch] $AllowInsecureLoopback,
        [Parameter()][ValidateRange(1, 600)][int] $HttpTimeoutSeconds = 30,
        [Parameter()][ValidateRange(1, 3600)][int] $RealtimeTimeoutSeconds = 30,
        [Parameter()][ValidateRange(0, 3)][int] $MaxGetRetries = 2
    )

    if ($Environment) {
        $environmentConfig = Resolve-MyWebApiEnvironment -Environment $Environment
        $resolvedBase = $environmentConfig.BaseUrl
        $resolvedAuthority = $environmentConfig.Authority
    } else {
        if (-not $BaseUrl) { throw 'Provide -Environment, or -BaseUrl (and -Authority for client-credentials).' }
        $resolvedBase = $BaseUrl
        $resolvedAuthority = $Authority
    }

    if (-not $AccessToken -and -not $ClientId) {
        throw 'Provide either -AccessToken, or -ClientId and -ClientSecret for client-credentials.'
    }
    if (-not $AccessToken -and -not $resolvedAuthority) {
        throw 'Authority is required for client-credentials: pass -Environment, or -Authority with -BaseUrl.'
    }
    if (-not $AccessToken -and -not $ClientSecret) {
        throw 'ClientSecret is required for client-credentials.'
    }

    # Validate before storing any mutable session state. Authority and API URLs are
    # deliberately separate so a token endpoint can never silently redirect credentials.
    $candidate = [pscustomobject]@{
        BaseUrl              = $resolvedBase.TrimEnd('/')
        Authority            = if ($resolvedAuthority) { $resolvedAuthority.TrimEnd('/') } else { $null }
        ClientId             = $ClientId
        ClientSecret         = $ClientSecret
        Scope                = $Scope
        DefaultTradePlatform = $DefaultTradePlatform
        AccessToken          = $AccessToken
        ExpiresAt            = if ($AccessToken) { [DateTimeOffset]::UtcNow.AddHours(1) } else { $null }
        TrustedTokenEndpoint = $TrustedTokenEndpoint
        AllowInsecureLoopback = [bool]$AllowInsecureLoopback
        HttpTimeoutSeconds   = $HttpTimeoutSeconds
        RealtimeTimeoutSeconds = $RealtimeTimeoutSeconds
        MaxGetRetries        = $MaxGetRetries
        CancellationSource    = [System.Threading.CancellationTokenSource]::new()
        RefreshGate          = [System.Threading.SemaphoreSlim]::new(1, 1)
        Disposed             = $false
    }
    $null = Assert-MyWebApiEndpoint -Value $candidate.BaseUrl -Name 'BaseUrl' -Context $candidate
    if ($candidate.Authority) {
        $null = Assert-MyWebApiEndpoint -Value $candidate.Authority -Name 'Authority' -Context $candidate
    }
    if ($TrustedTokenEndpoint) {
        $null = Assert-MyWebApiEndpoint -Value $TrustedTokenEndpoint -Name 'TrustedTokenEndpoint' -Context $candidate
    }

    # Keep the old one-session convenience while returning an explicit immutable target
    # reference for callers that need independent sessions.
    $script:MyWebApiContext = $candidate
    if (-not $AccessToken) {
        [void](Get-MyWebApiToken -Connection $candidate)
    }
    return $candidate
}
