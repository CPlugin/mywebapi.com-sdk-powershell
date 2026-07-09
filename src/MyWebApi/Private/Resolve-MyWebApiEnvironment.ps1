function Resolve-MyWebApiEnvironment {
    # Maps a named environment preset to its base URL + OIDC authority.
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('Staging','Production')][string] $Environment)
    $presets = @{
        Staging    = @{ BaseUrl = 'https://pre.mywebapi.com';   Authority = 'https://pre.auth.cplugin.net' }
        Production = @{ BaseUrl = 'https://cloud.mywebapi.com'; Authority = 'https://auth.cplugin.net' }
    }
    return $presets[$Environment]
}
