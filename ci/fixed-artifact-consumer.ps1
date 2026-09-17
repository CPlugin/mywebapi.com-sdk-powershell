# Bounded consumer smoke for the fixed MyWebApi 0.2.1 artifact or nupkg.
[CmdletBinding()]
param(
    [Parameter()][string] $ArtifactDir,
    [Parameter()][string] $PackagePath,
    [Parameter(Mandatory)][string] $ServerScript
)
$ErrorActionPreference = 'Stop'
if (-not $ArtifactDir -and -not $PackagePath) { throw 'Provide -ArtifactDir or -PackagePath.' }
$stateA = Join-Path $PSScriptRoot 'fixed-a-state.json'
$stateB = Join-Path $PSScriptRoot 'fixed-b-state.json'
$stateC = Join-Path $PSScriptRoot 'fixed-c-state.json'
$stateD = Join-Path $PSScriptRoot 'fixed-d-state.json'
$portA = Join-Path $PSScriptRoot 'fixed-a-port.txt'
$portB = Join-Path $PSScriptRoot 'fixed-b-port.txt'
$portC = Join-Path $PSScriptRoot 'fixed-c-port.txt'
$portD = Join-Path $PSScriptRoot 'fixed-d-port.txt'
$extractDir = Join-Path $PSScriptRoot 'fixed-package-extract'
Remove-Item -Force -Recurse -ErrorAction SilentlyContinue $stateA,$stateB,$stateC,$stateD,$portA,$portB,$portC,$portD,$extractDir
$servers = @()
$moduleImported = $false
function Start-Fake([string]$State,[string]$Port,[string]$TokenTarget) {
    $args = @($ServerScript,'--port','0','--state-file',$State,'--port-file',$Port)
    if ($TokenTarget) { $args += @('--token-target-file',$TokenTarget) }
    $p = Start-Process -FilePath python3 -ArgumentList $args -PassThru
    for ($i = 0; $i -lt 50 -and -not (Test-Path $Port); $i++) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path $Port)) { throw "Fake server did not start: $State" }
    return $p
}
function State([string]$BaseUrl) { Invoke-RestMethod -Method Get -Uri "$BaseUrl/__state" -OperationTimeoutSeconds 5 -ConnectionTimeoutSeconds 5 }
function Assert-Throws([scriptblock]$Action,[string]$Pattern) {
    try { & $Action; throw "Expected failure matching '$Pattern'." }
    catch { if ($_.Exception.Message -notmatch $Pattern) { throw } }
}
try {
    if ($PackagePath) {
        if (-not (Test-Path $PackagePath)) { throw "Package not found: $PackagePath" }
        if ((Get-Item $PackagePath).Length -le 0) { throw 'Package has zero bytes.' }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory((Resolve-Path $PackagePath), $extractDir)
        $ArtifactDir = $extractDir
    }
    $manifestPath = Join-Path $ArtifactDir 'MyWebApi.psd1'
    if (-not (Test-Path $manifestPath)) { throw "MyWebApi.psd1 missing from artifact: $ArtifactDir" }
    $manifest = Test-ModuleManifest -Path $manifestPath
    if ($manifest.Version -ne [version]'0.2.1') { throw "Expected module 0.2.1, got $($manifest.Version)." }
    Import-Module $manifestPath -Force
    $moduleImported = $true
    $exports = @(Get-Command -Module MyWebApi)
    if ($exports.Count -lt 183) { throw "Expected full export surface, got $($exports.Count)." }
    if (-not (Get-Command Get-MT4AdmBalanceCheck).Parameters.ContainsKey('Connection')) { throw 'Generated connection parameter missing.' }
    if (-not (Get-Command Invoke-MT4AdmBalanceFix).Parameters.ContainsKey('Confirm')) { throw 'SupportsShouldProcess missing from write cmdlet.' }
    if (-not (Get-Command Connect-MT4Realtime).Parameters.ContainsKey('Session')) { throw 'Realtime session parameter missing.' }

    # Public HTTPS is mandatory; loopback HTTP is test-only and explicit.
    Assert-Throws { Connect-MyWebApi -BaseUrl 'http://127.0.0.1:1' -AccessToken 'synthetic' | Out-Null } 'HTTPS|loopback'

    $servers += Start-Fake $stateA $portA $null
    $servers += Start-Fake $stateB $portB $null
    $servers += Start-Fake $stateD $portD $null
    $servers += Start-Fake $stateC $portC $portD
    $baseA = "http://127.0.0.1:$([int](Get-Content -Raw $portA))"
    $baseB = "http://127.0.0.1:$([int](Get-Content -Raw $portB))"
    $baseC = "http://127.0.0.1:$([int](Get-Content -Raw $portC))"
    $baseD = "http://127.0.0.1:$([int](Get-Content -Raw $portD))"
    $a = Connect-MyWebApi -BaseUrl $baseA -AccessToken 'token-a' -AllowInsecureLoopback -DefaultTradePlatform 'tp-a' -HttpTimeoutSeconds 1 -RealtimeTimeoutSeconds 2
    $b = Connect-MyWebApi -BaseUrl $baseB -AccessToken 'token-b' -AllowInsecureLoopback -DefaultTradePlatform 'tp-b'
    Get-MT4ServerTime -Connection $a -TradePlatform 'tp-a' | Out-Null
    Get-MT4ServerTime -Connection $b -TradePlatform 'tp-b' | Out-Null
    if (@((State $baseA).requests | Where-Object path -like '*tp-a*').Count -eq 0) { throw 'Connection A did not reach target A.' }
    if (@((State $baseB).requests | Where-Object path -like '*tp-b*').Count -eq 0) { throw 'Connection B did not reach target B.' }
    if (@((State $baseA).requests | Where-Object path -like '*tp-b*').Count -ne 0) { throw 'Connection B leaked into target A.' }
    if (@((State $baseB).requests | Where-Object path -like '*tp-a*').Count -ne 0) { throw 'Connection A leaked into target B.' }
    if ($a.HttpTimeoutSeconds -ne 1 -or $a.RealtimeTimeoutSeconds -ne 2) { throw 'Session deadline settings were not retained.' }

    # Discovery is not allowed to redirect a client secret to a different origin.
    $syntheticSecret = ConvertTo-SecureString 'synthetic-secret' -AsPlainText -Force
    Assert-Throws { Connect-MyWebApi -BaseUrl $baseC -Authority $baseC -ClientId 'client-a' -ClientSecret $syntheticSecret -AllowInsecureLoopback -HttpTimeoutSeconds 1 | Out-Null } 'outside Authority|TrustedTokenEndpoint'
    $crossState = State $baseD
    if (@($crossState.requests | Where-Object path -eq '/oauth/token').Count -ne 0) { throw 'Cross-origin discovery sent a client secret to the untrusted token origin.' }
    if (@($crossState.requests | Where-Object { $_.oauth_form.secret_present }).Count -ne 0) { throw 'Cross-origin token request contained a secret.' }

    # Safe GET retries are bounded (initial attempt plus two retries); writes are one-shot by contract.
    $before503 = @((State $baseA).requests | Where-Object path -like '*http503*').Count
    try { Get-MT4ServerTime -Connection $a -TradePlatform 'http503' -ErrorAction Stop | Out-Null } catch { }
    $after503 = @((State $baseA).requests | Where-Object path -like '*http503*').Count
    if (($after503 - $before503) -ne 3) { throw "Expected 3 bounded safe attempts (configured MaxGetRetries=2), saw $($after503 - $before503)." }

    # Disconnect cancels the session source and prevents subsequent work.
    Disconnect-MyWebApi -Connection $b
    if (-not $b.CancellationSource.IsCancellationRequested) { throw 'Disconnect did not cancel the session token.' }
    Assert-Throws { Get-MT4ServerTime -Connection $b -TradePlatform 'tp-b' | Out-Null } 'disconnected|cancelled|cancel'

    # Realtime status/tick path plus background fault propagation.
    $rt = Connect-MT4Realtime -Session $a -TradePlatform 'tp-a'
    Register-MT4Realtime -Connection $rt -Category Ticks -Symbol 'EURUSD' -TimeoutSeconds 5
    $events = @(Receive-MT4Realtime -Connection $rt -TimeoutSeconds 5)
    if (@($events | Where-Object Method -eq 'OnConnectionStatus').Count -eq 0) { throw 'Realtime status event was not received.' }
    if (@($events | Where-Object Method -eq 'OnTick').Count -eq 0) { throw 'Realtime tick event was not received.' }
    Stop-Process -Id $servers[0].Id -Force
    Start-Sleep -Seconds 2
    $faultSeen = $false
    try { @(Receive-MT4Realtime -Connection $rt -TimeoutSeconds 2) | Out-Null }
    catch { if ($_.Exception.Message -match 'fault|connection|closed') { $faultSeen = $true } else { throw } }
    if (-not $faultSeen) { throw 'Background realtime fault was not propagated to Receive-MT4Realtime.' }
    try { Disconnect-MT4Realtime -Connection $rt -ErrorAction Stop } catch { }
    Disconnect-MyWebApi -Connection $a
    [pscustomobject]@{ status = 'ok'; exports = $exports.Count; package = [bool]$PackagePath; contexts = 'independent'; oauth_cross_origin_secret_sent = $false; safe_get_attempts = 3; realtime = 'status+tick+fault'; cancellation = $true } | ConvertTo-Json -Compress
}
finally {
    foreach ($p in $servers) { if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } }
    if ($moduleImported) { Remove-Module MyWebApi -ErrorAction SilentlyContinue }
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue $extractDir,$stateA,$stateB,$stateC,$stateD,$portA,$portB,$portC,$portD
}