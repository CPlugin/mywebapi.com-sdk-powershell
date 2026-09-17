function Get-MyWebApiTradePlatform {
    <#
    .SYNOPSIS
        Lists the trade platforms your credentials can access (platform discovery).
    #>
    [CmdletBinding()]
    param([object] $Connection)
    $ctx = Resolve-MyWebApiContext -Connection $Connection
    $baseUri = Assert-MyWebApiEndpoint -Value ([string](Get-MyWebApiContextProperty -Context $ctx -Name 'BaseUrl')) -Name 'BaseUrl' -Context $ctx
    $token = Get-MyWebApiToken -Connection $ctx
    Assert-MyWebApiNotCancelled -Context $ctx
    return Invoke-MyWebApiHttpJson -Context $ctx -Method Get -Uri ("{0}/api/TradePlatforms" -f $baseUri.AbsoluteUri.TrimEnd('/')) -Headers @{ Authorization = "Bearer $token"; Accept = 'application/json' }
}
