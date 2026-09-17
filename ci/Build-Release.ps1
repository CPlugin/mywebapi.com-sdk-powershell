#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter()][string] $SourceModule = (Join-Path $PSScriptRoot '../src/MyWebApi'),
    [Parameter(Mandatory)][string] $OutputDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$source = (Resolve-Path -LiteralPath $SourceModule).Path
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
$stage = Join-Path $output 'module'
$packageDirectory = Join-Path $output 'package'
$localRepository = Join-Path $output 'local-repository'
$repositoryName = "MyWebApiReleaseLocal_$PID"

if (-not (Test-Path -LiteralPath $output -PathType Container)) {
    New-Item -ItemType Directory -Path $output -Force | Out-Null
}
foreach ($path in @($stage, $packageDirectory, $localRepository)) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

$links = @(
    Get-ChildItem -LiteralPath $source -Force -Recurse -Attributes ReparsePoint -ErrorAction SilentlyContinue
)
if ($links.Count -gt 0) {
    throw "Refusing to package a module containing reparse points: $($links.FullName -join ', ')"
}

Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $stage -Recurse -Force
$generatedManifest = Join-Path $stage 'generated-exports.psd1'
if (Test-Path -LiteralPath $generatedManifest) {
    Remove-Item -LiteralPath $generatedManifest -Force
}

$manifestPath = Join-Path $stage 'MyWebApi.psd1'
$manifest = Test-ModuleManifest -Path $manifestPath
if ($manifest.Name -ne 'MyWebApi') {
    throw "Unexpected module name '$($manifest.Name)'."
}
if ($manifest.PowerShellVersion -ne [version]'7.4') {
    throw "MyWebApi requires PowerShell $($manifest.PowerShellVersion), expected 7.4."
}
$version = $manifest.Version.ToString()

Import-Module Microsoft.PowerShell.PSResourceGet -ErrorAction Stop
try {
    $repositoryUri = ([System.Uri]::new($localRepository)).AbsoluteUri
    Register-PSResourceRepository -Name $repositoryName -Uri $repositoryUri -ApiVersion Local -Trusted -Force | Out-Null
    Publish-PSResource -Path $stage -DestinationPath $packageDirectory -Repository $repositoryName -ErrorAction Stop
} finally {
    Unregister-PSResourceRepository -Name $repositoryName -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $localRepository) {
        Remove-Item -LiteralPath $localRepository -Recurse -Force
    }
}

$packages = @(Get-ChildItem -LiteralPath $packageDirectory -Filter '*.nupkg' -File)
if ($packages.Count -ne 1) {
    throw "Expected exactly one package from PSResourceGet, found $($packages.Count)."
}
$nupkg = $packages[0].FullName
$expectedName = "MyWebApi.$version.nupkg"
if ($packages[0].Name -ne $expectedName) {
    throw "Package name $($packages[0].Name) does not match manifest version $version."
}
$packageBytes = $packages[0].Length
if ($packageBytes -le 0) {
    throw 'Package has zero bytes.'
}

[pscustomobject]@{
    Module = $manifest.Name
    Version = $version
    Stage = $stage
    Package = $nupkg
    PackageBytes = $packageBytes
} | ConvertTo-Json -Compress
