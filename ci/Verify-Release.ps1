#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PackagePath,
    [Parameter()][string] $ProbePath = (Join-Path $PSScriptRoot 'fixed-artifact-consumer.ps1'),
    [Parameter()][string] $ServerScript = (Join-Path $PSScriptRoot 'fake-server.py')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$package = (Resolve-Path -LiteralPath $PackagePath).Path
$probe = (Resolve-Path -LiteralPath $ProbePath).Path
$server = (Resolve-Path -LiteralPath $ServerScript).Path
$packageInfo = Get-Item -LiteralPath $package
if ($packageInfo.Length -le 0) {
    throw "Package has zero bytes: $package"
}
if ([System.IO.Path]::GetExtension($package) -ne '.nupkg') {
    throw "Expected a .nupkg artifact, got '$package'."
}
if ([System.IO.Path]::GetExtension($server) -ne '.py') {
    throw "Expected a Python loopback fixture, got '$server'."
}
if ([System.IO.Path]::GetFileName($package) -notmatch '^MyWebApi\.(?<version>\d+\.\d+\.\d+)\.nupkg$') {
    throw "Package filename must contain a stable semantic version: $package"
}
$packageVersion = $Matches.version

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($package)
try {
    $manifestEntry = $zip.Entries | Where-Object FullName -eq 'MyWebApi.psd1'
    if ($null -eq $manifestEntry) {
        throw 'The nupkg does not contain MyWebApi.psd1 at its module root.'
    }
    $nuspecEntry = $zip.Entries | Where-Object FullName -eq 'MyWebApi.nuspec'
    if ($null -eq $nuspecEntry) {
        throw 'The nupkg does not contain MyWebApi.nuspec at its package root.'
    }
    $reader = [System.IO.StreamReader]::new($nuspecEntry.Open())
    try {
        $nuspec = [System.Xml.XmlDocument]::new()
        $nuspec.LoadXml($reader.ReadToEnd())
    } finally {
        $reader.Dispose()
    }
    $namespace = [System.Xml.XmlNamespaceManager]::new($nuspec.NameTable)
    $namespace.AddNamespace('n', 'http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd')
    $id = $nuspec.SelectSingleNode('/n:package/n:metadata/n:id', $namespace)
    $version = $nuspec.SelectSingleNode('/n:package/n:metadata/n:version', $namespace)
    if ($null -eq $id -or $id.InnerText -ne 'MyWebApi') { throw 'Nuspec id is not MyWebApi.' }
    if ($null -eq $version -or $version.InnerText -ne $packageVersion) { throw 'Nuspec version does not match the package filename.' }
} finally {
    $zip.Dispose()
}

& pwsh -NoProfile -File $probe -PackagePath $package -ServerScript $server
if ($LASTEXITCODE -ne 0) {
    throw "Published-package consumer probe failed with exit code $LASTEXITCODE."
}

[pscustomobject]@{
    Package = $package
    PackageBytes = $packageInfo.Length
    ConsumerProbe = $probe
    LoopbackFixture = $server
    Status = 'ok'
} | ConvertTo-Json -Compress
