#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter()][string] $Tag = $env:GITHUB_REF_NAME,
    [Parameter()][string] $ManifestPath = (Join-Path $PSScriptRoot '../src/MyWebApi/MyWebApi.psd1')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($Tag)) {
    throw 'A release tag is required.'
}
if ($Tag -notmatch '^v(?<version>\d+\.\d+\.\d+)$') {
    throw "Release tag '$Tag' is not a stable vMAJOR.MINOR.PATCH tag."
}
$manifest = Test-ModuleManifest -Path (Resolve-Path -LiteralPath $ManifestPath)
$tagVersion = [version]$Matches.version
if ($manifest.Version -ne $tagVersion) {
    throw "Tag $Tag does not match manifest version $($manifest.Version)."
}
if ($manifest.Name -ne 'MyWebApi') {
    throw "Unexpected module name '$($manifest.Name)'."
}

[pscustomobject]@{
    Tag = $Tag
    Module = $manifest.Name
    Version = $manifest.Version.ToString()
    Status = 'ok'
} | ConvertTo-Json -Compress
