function New-MyWebApiRealtime {
    # Builds and starts a hub connection for the given hub path, returns a wrapper object.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('mt4','mt5')][string] $Hub,
        [string] $TradePlatform
    )
    if (-not $script:MyWebApiContext) { throw 'Not connected. Call Connect-MyWebApi first.' }
    $ctx = $script:MyWebApiContext
    $token = Get-MyWebApiToken
    $url = "$($ctx.BaseUrl)/hubs/$Hub/v2?signalr_token=$([uri]::EscapeDataString($token))"

    $builder = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilder]::new()
    $null = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilderHttpExtensions]::WithUrl($builder, $url)
    $null = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilderExtensions]::WithAutomaticReconnect($builder)
    $connection = $builder.Build()

    $sink = [MyWebApi.RealtimeSink]::new($connection)
    foreach ($m in 'OnTick','OnTradeUpdate','OnUserUpdate','OnSymbolUpdate','OnMarginCall','OnConnectionStatus') {
        $sink.On($m)
    }
    $sink.StartAsync().GetAwaiter().GetResult()

    [pscustomobject]@{
        PSTypeName    = 'MyWebApi.RealtimeConnection'
        Hub           = $Hub
        TradePlatform = if ($TradePlatform) { $TradePlatform } else { $ctx.DefaultTradePlatform }
        Sink          = $sink
    }
}
