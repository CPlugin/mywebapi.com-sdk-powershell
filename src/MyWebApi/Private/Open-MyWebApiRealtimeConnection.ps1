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
    if (-not ('MyWebApi.RealtimeSink' -as [type])) {
        throw 'Real-time support requires the SignalR client assemblies. Reinstall the packaged module, or run scripts/restore-lib.sh when working from source.'
    }
    if (-not $script:MyWebApiContext) { throw 'Not connected. Call Connect-MyWebApi first.' }
    $ctx = $script:MyWebApiContext

    # * The v2 hub's OnConnectedAsync REQUIRES a `tradePlatform` query parameter (a GUID
    #   the credential is authorized for); without it the server throws a HubException and
    #   closes the socket right after the handshake (StartAsync succeeds, then State flips
    #   to Disconnected). Resolve it exactly like the REST pipeline does.
    $tp = if ($TradePlatform) { $TradePlatform } else { $ctx.DefaultTradePlatform }
    if (-not $tp) { throw 'No trade platform: pass -TradePlatform or set -DefaultTradePlatform on Connect-MyWebApi.' }

    $token = Get-MyWebApiToken
    $url = "$($ctx.BaseUrl)/hubs/$Hub/v2?tradePlatform=$([uri]::EscapeDataString($tp))&signalr_token=$([uri]::EscapeDataString($token))"

    $builder = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilder]::new()
    $null = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilderHttpExtensions]::WithUrl($builder, $url)
    $null = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilderExtensions]::WithAutomaticReconnect($builder)
    $connection = $builder.Build()

    $sink = [MyWebApi.RealtimeSink]::new($connection)
    $sink.On('OnConnectionStatus')
    if ($Hub -eq 'mt4') { $sink.On('OnTick') }
    # * [void]: GetResult() on a void Task returns a VoidTaskResult sentinel that would
    #   otherwise leak into the pipeline, making this function emit an array instead of
    #   the single connection object.
    [void]$sink.StartAsync().GetAwaiter().GetResult()

    [pscustomobject]@{
        PSTypeName    = 'MyWebApi.RealtimeConnection'
        Hub           = $Hub
        TradePlatform = $tp
        Sink          = $sink
    }
}
