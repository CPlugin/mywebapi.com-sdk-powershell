function Open-MyWebApiRealtimeConnection {
    # Builds and starts a hub connection for the given hub path, returns a wrapper object.
    # * Named 'Open-' (not 'New-') on purpose: it has a real side effect (opens a live
    #   network connection via StartAsync()), so the 'New' verb would make
    #   PSUseShouldProcessForStateChangingFunctions flag it. It is Private/unexported and
    #   always called unconditionally by the public Connect-MT4Realtime/Connect-MT5Realtime
    #   cmdlets, so ShouldProcess plumbing here would be unreachable boilerplate.
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
    $sink.On('OnConnectionStatus')
    if ($Hub -eq 'mt4') { $sink.On('OnTick') }
    $sink.StartAsync().GetAwaiter().GetResult()

    [pscustomobject]@{
        PSTypeName    = 'MyWebApi.RealtimeConnection'
        Hub           = $Hub
        TradePlatform = if ($TradePlatform) { $TradePlatform } else { $ctx.DefaultTradePlatform }
        Sink          = $sink
    }
}
