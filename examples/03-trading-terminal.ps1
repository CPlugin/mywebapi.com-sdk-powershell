# * Example 03 — Trading Terminal: live prices + open trades + order lifecycle.
#
# * Need credentials? Create API keys and manage trade platforms in the Toolbox:
# *   staging: https://pre.toolbox.cplugin.com   ·   prod: https://toolbox.cplugin.com
#
# The full loop demonstrating both read and write paths:
#   1. Subscribe to live tick prices for a symbol and wait for the first tick.
#   2. List all currently open trades (paged fetch via -All).
#   3. Open a market order (Buy) at the current ask price.
#   4. Close the same order at the current bid price.
#
# ! ORDER SAFETY — DRY-RUN BY DEFAULT:
#   Without -Live this script prints the exact request body it WOULD send and
#   exits WITHOUT placing any real orders. Only pass -Live when connected to a
#   test/demo broker server and you are prepared to accept a real position.
#
# Run (dry-run — safe):
#   pwsh examples/03-trading-terminal.ps1
#
# Run (LIVE — places real orders!):
#   pwsh examples/03-trading-terminal.ps1 -Live
#
# Required env vars (see .env.example / examples/README.md):
#   WEBAPI_CLIENT_ID, WEBAPI_CLIENT_SECRET  — OAuth2 client-credentials
#   WEBAPI_ENV                              — 'Staging' (default) or 'Production'
#
# Optional:
#   WEBAPI_TRADE_PLATFORM — trade platform id; auto-selected if you have exactly
#                           one, required if you have several.
#   WEBAPI_SYMBOL         — symbol to trade (default: EURUSD)
#   WEBAPI_VOLUME         — volume in MT4 internal units (default: 10 = 0.1 lot)
#                           1 lot = 100 units; keep this small on a real server!

[CmdletBinding()]
param(
    # * Places real orders on the configured trade server. Omit for a safe,
    #   read-only dry-run that prints the request bodies instead of sending them.
    [switch] $Live
)

Import-Module ./src/MyWebApi/MyWebApi.psd1 -Force
. "$PSScriptRoot/_shared.ps1"

$symbol = if ($env:WEBAPI_SYMBOL) { $env:WEBAPI_SYMBOL } else { 'EURUSD' }

# * Volume in MT4 internal units (1 lot = 100). Default 10 = 0.1 lot.
$volume = if ($env:WEBAPI_VOLUME) { [int]$env:WEBAPI_VOLUME } else { 10 }

Write-Host '=== MyWebApi SDK — Example 03: Trading Terminal ===' -ForegroundColor Cyan
Write-Host ''

Connect-FromEnv
$tp = Resolve-TradePlatform

Write-Host "Platform : $tp"
Write-Host "Symbol   : $symbol"
Write-Host ("Volume   : {0} units ({1:N2} lots)" -f $volume, ($volume / 100))
Write-Host ("Mode     : {0}" -f $(if ($Live) { '*** LIVE — REAL ORDERS ***' } else { 'DRY-RUN (safe, pass -Live to place real orders)' }))
Write-Host ''

# ---------------------------------------------------------------------------
# * Step 1 — Subscribe to ticks and wait for the first one to get a fresh
#   bid/ask before trading. Register BEFORE receiving so no event is missed.
# ---------------------------------------------------------------------------
Write-Host 'Waiting for first tick...'
$rt = Connect-MT4Realtime -TradePlatform $tp
Register-MT4Realtime -Connection $rt -Category Ticks -Symbol $symbol

$tick = Receive-MT4Realtime -Connection $rt -TimeoutSeconds 15 |
    Where-Object { $_.Method -eq 'OnTick' } |
    Select-Object -First 1

if (-not $tick) {
    Write-Error "No tick received within 15s — is the platform pumping? Check that the market is open and the price feed is active."
    Disconnect-MT4Realtime -Connection $rt
    Disconnect-MyWebApi
    return
}

$bid = [double]$tick.Payload.bid
$ask = [double]$tick.Payload.ask
Write-Host ("Price received: bid={0:F5} ask={1:F5}" -f $bid, $ask)

# ---------------------------------------------------------------------------
# * Step 2 — List open trades (paged fetch, -All follows every cursor).
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host 'Fetching open trades...'
try {
    $trades = @(Get-MT4TradesGet -TradePlatform $tp -All)
    Write-Host ("Open positions: {0}" -f $trades.Count)
    foreach ($t in $trades | Select-Object -First 5) {
        Write-Host ("  #{0}  {1}  vol={2}  profit={3}" -f $t.order, $t.symbol, $t.volume, $t.profit)
    }
    if ($trades.Count -gt 5) { Write-Host ("  ... and {0} more" -f ($trades.Count - 5)) }
} catch {
    Write-Error "Failed to fetch open trades: $($_.Exception.Message)"
}

# ---------------------------------------------------------------------------
# * Step 3 — Open a market Buy order (or print the dry-run request body).
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- Opening market order ---'

$openBody = @{
    tradeTransactionType = 'OpenMarket'
    tradeCommand         = 'Buy'          # * Buy at market — filled at ask price.
    symbol               = $symbol
    volume               = $volume
    price                = $ask           # * Hint price; server replaces with live quote.
    sl                   = 0              # * No stop-loss for this example order.
    tp                   = 0              # * No take-profit.
    comment              = 'sdk-example-03'
}

$ticket = 0

if (-not $Live) {
    Write-Host '[DRY-RUN] Would submit OpenMarket:'
    $openBody | ConvertTo-Json
    Write-Host ''
    Write-Host 'Re-run with -Live to place the real order.'
} else {
    try {
        # * Idempotency-Key is STRONGLY recommended for trade mutations — a
        #   unique key per logical order prevents double-execution on retry.
        $key = [guid]::NewGuid().ToString()
        $res = Invoke-MT4TradeTransaction -TradePlatform $tp -Body $openBody -IdempotencyKey $key
        $ticket = $res.order
        if (-not $ticket) { throw 'Server returned no order ticket after OpenMarket' }
        Write-Host ("Order opened: ticket #{0}" -f $ticket)
    } catch {
        Write-Error "Failed to open market order: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# * Step 4 — Close the same position at the current bid (live only).
# ---------------------------------------------------------------------------
if ($Live -and $ticket -gt 0) {
    # * Brief pause to let the server process the open before the close arrives.
    Start-Sleep -Milliseconds 500

    Write-Host ''
    Write-Host '--- Closing market order ---'

    $closeBody = @{
        tradeTransactionType = 'CloseMarket'
        tradeCommand         = 'Sell'     # * Closing a Buy requires a Sell command.
        symbol               = $symbol
        volume               = $volume
        price                = $bid       # * Hint price; server replaces with live quote.
        order                = $ticket    # ! Must supply the original ticket to identify the position.
        sl                   = 0
        tp                   = 0
        comment              = 'sdk-example-03-close'
    }

    try {
        Invoke-MT4TradeTransaction -TradePlatform $tp -Body $closeBody -IdempotencyKey ([guid]::NewGuid().ToString())
        Write-Host ("Order #{0} closed." -f $ticket)
    } catch {
        Write-Error "Failed to close market order: $($_.Exception.Message)"
    }
}

if (-not $Live) {
    Write-Host ''
    Write-Host '[DRY-RUN] Script finished without touching the trade server.'
} else {
    Write-Host ''
    Write-Host 'Trading sequence complete.'
}

Disconnect-MT4Realtime -Connection $rt
Disconnect-MyWebApi
