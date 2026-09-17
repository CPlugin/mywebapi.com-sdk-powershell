#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PackagePath,
    [Parameter(Mandatory)][string] $ExtractDirectory,
    [Parameter(Mandatory)][string] $SbomPath,
    [Parameter(Mandatory)][string] $ProvenancePath,
    [Parameter(Mandatory)][string] $LockFilePath,
    [Parameter(Mandatory)][string] $ExpectedModuleVersion
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$package = (Resolve-Path -LiteralPath $PackagePath).Path
$extract = (Resolve-Path -LiteralPath $ExtractDirectory).Path
$sbomFile = (Resolve-Path -LiteralPath $SbomPath).Path
$lockFile = (Resolve-Path -LiteralPath $LockFilePath).Path
foreach ($path in @($package, $sbomFile, $lockFile)) {
    if ((Get-Item -LiteralPath $path).Length -le 0) { throw "Input file has zero bytes: $path" }
}

$manifestPath = Join-Path $extract 'MyWebApi.psd1'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "The extracted package has no root MyWebApi.psd1: $manifestPath"
}
$manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
if ($manifest.ModuleVersion.ToString() -ne $ExpectedModuleVersion) {
    throw "Module manifest version $($manifest.ModuleVersion) does not match package version $ExpectedModuleVersion."
}

$lock = Get-Content -LiteralPath $lockFile -Raw | ConvertFrom-Json
$runtime = $lock.dependencies.'net8.0'
$signalRLock = $runtime.'Microsoft.AspNetCore.SignalR.Client'
if ($null -eq $signalRLock -or [string]::IsNullOrWhiteSpace($signalRLock.resolved)) {
    throw 'The locked runtime graph has no resolved Microsoft.AspNetCore.SignalR.Client version.'
}
$expectedSignalRVersion = $signalRLock.resolved.ToString()

$sbom = Get-Content -LiteralPath $sbomFile -Raw | ConvertFrom-Json
if ($sbom.spdxVersion -ne 'SPDX-2.3') { throw "Expected SPDX-2.3 SBOM, got $($sbom.spdxVersion)." }
$packages = @($sbom.packages)
$files = @($sbom.files)
if ($packages.Count -eq 0) { throw 'The SPDX inventory contains no packages.' }
$dllFiles = @($files | Where-Object { $_.fileName -match '(?i)\.dll$' })
$physicalDlls = @(Get-ChildItem -LiteralPath $extract -File -Recurse | Where-Object { $_.Extension -ieq '.dll' })
if ($dllFiles.Count -ne $physicalDlls.Count -or $dllFiles.Count -eq 0) {
    throw "SPDX DLL inventory does not match the package contents (SBOM=$($dllFiles.Count), files=$($physicalDlls.Count))."
}
$sbomDllNames = @($dllFiles | ForEach-Object { $_.fileName })
$physicalDllNames = @($physicalDlls | ForEach-Object { [System.IO.Path]::GetRelativePath($extract, $_.FullName).Replace('\', '/') })
$missing = @(Compare-Object -ReferenceObject ($physicalDllNames | Sort-Object) -DifferenceObject ($sbomDllNames | Sort-Object) -PassThru | Where-Object { $_.SideIndicator -eq '<=' })
$extra = @(Compare-Object -ReferenceObject ($physicalDllNames | Sort-Object) -DifferenceObject ($sbomDllNames | Sort-Object) -PassThru | Where-Object { $_.SideIndicator -eq '=>' })
if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
    throw "SPDX DLL inventory differs from shipped files (missing=$($missing -join ', '); extra=$($extra -join ', '))."
}

$signalR = @($packages | Where-Object { $_.name -eq 'Microsoft.AspNetCore.SignalR.Client' })
if ($signalR.Count -ne 1 -or $signalR[0].versionInfo -ne $expectedSignalRVersion) {
    $actual = ($signalR | ForEach-Object { "$($_.name)@$($_.versionInfo)" }) -join ', '
    throw "Expected locked SignalR component Microsoft.AspNetCore.SignalR.Client@$expectedSignalRVersion in SPDX inventory; got $actual."
}
$signalRFile = "lib/Microsoft.AspNetCore.SignalR.Client.dll"
if ($sbomDllNames -notcontains $signalRFile) {
    throw "SPDX inventory does not evidence the shipped SignalR assembly: $signalRFile"
}

$packageHash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
$sbomHash = (Get-FileHash -LiteralPath $sbomFile -Algorithm SHA256).Hash.ToLowerInvariant()
$provenanceDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($ProvenancePath))
New-Item -ItemType Directory -Path $provenanceDirectory -Force | Out-Null
[ordered]@{
    schema = 'mywebapi-release-provenance-v1'
    'source-name' = 'MyWebApi'
    'source-version' = $ExpectedModuleVersion
    'package-sha256' = $packageHash
    'sbom-sha256' = $sbomHash
    module = [ordered]@{ name = 'MyWebApi'; version = $manifest.ModuleVersion.ToString() }
    runtime = [ordered]@{ name = 'Microsoft.AspNetCore.SignalR.Client'; version = $expectedSignalRVersion }
    sbom = [ordered]@{ format = 'SPDX-2.3'; packageCount = $packages.Count; shippedDllCount = $dllFiles.Count }
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ProvenancePath -Encoding utf8

[pscustomobject]@{
    Status = 'ok'
    Module = 'MyWebApi'
    Version = $ExpectedModuleVersion
    PackageCount = $packages.Count
    ShippedDllCount = $dllFiles.Count
    SignalRVersion = $expectedSignalRVersion
    PackageSha256 = $packageHash
    SbomSha256 = $sbomHash
    Provenance = [System.IO.Path]::GetFullPath($ProvenancePath)
} | ConvertTo-Json -Compress
