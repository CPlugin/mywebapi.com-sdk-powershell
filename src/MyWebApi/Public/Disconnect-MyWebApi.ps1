function Disconnect-MyWebApi {
    <#
    .SYNOPSIS
        Clears the current WebAPI session and zeroes the cached token.
    #>
    [CmdletBinding()]
    param()
    $script:MyWebApiContext = $null
}
