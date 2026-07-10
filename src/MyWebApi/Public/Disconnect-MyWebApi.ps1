function Disconnect-MyWebApi {
    <#
    .SYNOPSIS
        Clears the current WebAPI session and zeroes the cached token.
    #>
    [CmdletBinding()]
    param()
    if ($script:MyWebApiContext -and ($script:MyWebApiContext.ClientSecret -is [System.Security.SecureString])) {
        try {
            $script:MyWebApiContext.ClientSecret.Dispose()
        } catch {
            # * Non-fatal: already disposed, or disposal unsupported on this platform.
            Write-Verbose "Skipping SecureString disposal: $($_.Exception.Message)"
        }
    }
    $script:MyWebApiContext = $null
}
