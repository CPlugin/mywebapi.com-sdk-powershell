function Open-MyWebApiRealtimeConnection {
    # Opens one explicit SignalR connection for the supplied REST session. Automatic
    # reconnect is intentionally disabled: the protocol's required signalr_token is
    # embedded in the handshake URL, so reconnecting with a stale query token would be
    # unsafe. Call Connect-MT*Realtime again after a disconnect to obtain a fresh token.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('mt4','mt5')][string] $Hub,
        [string] $TradePlatform,
        [object] $Connection
    )
    if (-not ('MyWebApi.RealtimeSink' -as [type])) {
        throw 'Real-time support requires compatible SignalR client assemblies. Reinstall the packaged module or run scripts/restore-lib.sh with the supported PowerShell runtime.'
    }

    $ctx = Resolve-MyWebApiContext -Connection $Connection
    $baseUri = Assert-MyWebApiEndpoint -Value ([string](Get-MyWebApiContextProperty -Context $ctx -Name 'BaseUrl')) -Name 'BaseUrl' -Context $ctx
    $tpDefault = Get-MyWebApiContextProperty -Context $ctx -Name 'DefaultTradePlatform'
    $tp = if ($TradePlatform) { $TradePlatform } else { $tpDefault }
    if (-not $tp) { throw 'No trade platform: pass -TradePlatform or set -DefaultTradePlatform on Connect-MyWebApi.' }

    $token = Get-MyWebApiToken -Connection $ctx
    $url = "{0}/hubs/{1}/v2?tradePlatform={2}&signalr_token={3}" -f $baseUri.AbsoluteUri.TrimEnd('/'), $Hub, [uri]::EscapeDataString($tp), [uri]::EscapeDataString($token)
    $safeUrl = $url -replace '(?i)(signalr_token=)[^&]*', '$1<REDACTED>'

    try {
        $builder = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilder]::new()
        # signalr_token is retained because the v2 server may require this protocol.
        # Automatic reconnect is not enabled; a fresh Connect call renews this URL/token.
        $null = [Microsoft.AspNetCore.SignalR.Client.HubConnectionBuilderHttpExtensions]::WithUrl($builder, $url)
        $connectionObject = $builder.Build()
        $sink = [MyWebApi.RealtimeSink]::new($connectionObject)
        $sink.On('OnConnectionStatus')
        if ($Hub -eq 'mt4') { $sink.On('OnTick') }

        $startTask = $sink.StartAsync()
        $timeout = Get-MyWebApiContextProperty -Context $ctx -Name 'RealtimeTimeoutSeconds'
        if ($null -eq $timeout -or [int]$timeout -lt 1) { $timeout = 30 }
        if (-not $startTask.Wait([Math]::Min([int]$timeout, 3600) * 1000)) {
            try { $sink.Dispose() } catch { Write-Verbose "Realtime cleanup failed after timeout: $($_.Exception.Message)" }
            throw "Timed out opening SignalR connection after $timeout second(s) ($safeUrl)."
        }
        [void]$startTask.GetAwaiter().GetResult()

        [pscustomobject]@{
            PSTypeName    = 'MyWebApi.RealtimeConnection'
            Hub           = $Hub
            TradePlatform = $tp
            Session       = $ctx
            Sink          = $sink
            UrlForDiagnostics = $safeUrl
        }
    } catch {
        $message = $_.Exception.Message -replace '(?i)(signalr_token=)[^&\s]*', '$1<REDACTED>'
        throw "Failed to open SignalR connection at ${safeUrl}: $message"
    }
}
