function Connect-MyWebApi {
    <#
    .SYNOPSIS
        Establishes a session against the WebAPI v2 (OAuth2 client-credentials).
    .DESCRIPTION
        Acquires a bearer token via IdentityServer client-credentials, or accepts a
        pre-obtained token, and stores it for subsequent cmdlets. The client secret is
        held as a SecureString and never logged. Use -Environment for a preset, or
        -BaseUrl/-Authority for a custom deployment. API keys and trade platforms are
        created and managed in the CPlugin Toolbox (https://toolbox.cplugin.com for
        production, https://pre.toolbox.cplugin.com for staging).
    .PARAMETER Environment
        Named preset: 'Staging' or 'Production'. Sets BaseUrl and Authority.
    .PARAMETER BaseUrl
        Custom base URL of the API (when not using -Environment).
    .PARAMETER Authority
        Custom OIDC authority (IdentityServer) base URL used for token acquisition.
    .PARAMETER ClientId
        OAuth2 client id.
    .PARAMETER ClientSecret
        OAuth2 client secret, as a SecureString.
    .PARAMETER AccessToken
        A pre-obtained bearer token (skips the token endpoint; no auto-refresh).
    .PARAMETER Scope
        OAuth2 scope requested. Defaults to 'webapi'.
    .PARAMETER DefaultTradePlatform
        Default {tradePlatform} value used when a cmdlet omits -TradePlatform.
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
        [Parameter()][string] $DefaultTradePlatform
    )

    # Resolve base URL + authority: preset OR explicit.
    if ($Environment) {
        $env = Resolve-MyWebApiEnvironment -Environment $Environment
        $resolvedBase = $env.BaseUrl
        $resolvedAuthority = $env.Authority
    } else {
        if (-not $BaseUrl) { throw 'Provide -Environment, or -BaseUrl (and -Authority for client-credentials).' }
        $resolvedBase = $BaseUrl
        $resolvedAuthority = $Authority
    }

    if (-not $AccessToken -and -not $ClientId) {
        throw 'Provide either -AccessToken, or -ClientId and -ClientSecret for client-credentials.'
    }

    $script:MyWebApiContext = @{
        BaseUrl              = $resolvedBase.TrimEnd('/')
        Authority            = if ($resolvedAuthority) { $resolvedAuthority.TrimEnd('/') } else { $null }
        ClientId             = $ClientId
        ClientSecret         = $ClientSecret
        Scope                = $Scope
        DefaultTradePlatform = $DefaultTradePlatform
        AccessToken          = $AccessToken
        ExpiresAt            = $null
    }

    if (-not $AccessToken) {
        # Prime the token now so connection errors surface at Connect time.
        [void](Get-MyWebApiToken)
    }
}
