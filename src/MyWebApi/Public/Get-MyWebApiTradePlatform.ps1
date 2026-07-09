function Get-MyWebApiTradePlatform {
    <#
    .SYNOPSIS
        Lists the trade platforms your credentials can access (platform discovery).
    .DESCRIPTION
        Calls the v1, unversioned /api/TradePlatforms endpoint, which returns a plain
        JSON array (NOT the v2 { data, error, meta } envelope). Use the returned 'id'
        as the -TradePlatform value for other cmdlets. Trade platforms are created and
        managed in the CPlugin Toolbox.
    #>
    [CmdletBinding()]
    param()
    if (-not $script:MyWebApiContext) { throw 'Not connected. Call Connect-MyWebApi first.' }
    $token = Get-MyWebApiToken
    Invoke-RestMethod -Method Get -Uri "$($script:MyWebApiContext.BaseUrl)/api/TradePlatforms" `
        -Headers @{ Authorization = "Bearer $token"; Accept = 'application/json' }
}
