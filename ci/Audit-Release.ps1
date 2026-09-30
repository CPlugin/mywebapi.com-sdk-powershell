#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $PackagePath,
    [Parameter()][string] $GitleaksPath = 'gitleaks',
    [Parameter()][string] $OutputDirectory = (Join-Path $PSScriptRoot '../audit-output')
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$package = (Resolve-Path -LiteralPath $PackagePath).Path
$packageInfo = Get-Item -LiteralPath $package
if ($packageInfo.Length -le 0) { throw "Package has zero bytes: $package" }
if (Test-Path -LiteralPath $GitleaksPath -PathType Leaf) {
    $gitleaks = (Resolve-Path -LiteralPath $GitleaksPath).Path
} else {
    $gitleaks = (Get-Command $GitleaksPath -ErrorAction Stop).Source
}
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
$extract = Join-Path $output 'extracted'
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
New-Item -ItemType Directory -Path $extract -Force | Out-Null
Expand-Archive -LiteralPath $package -DestinationPath $extract
$files = @(Get-ChildItem -LiteralPath $extract -File -Recurse)
if ($files.Count -eq 0) { throw 'The extracted package contains no files.' }

$logPath = Join-Path $output 'gitleaks.log'
$reportPath = Join-Path $output 'gitleaks.sarif'
$scanOutput = @(
    & $gitleaks dir $extract --no-banner --no-color --redact --exit-code 1 --report-format sarif --report-path $reportPath --verbose 2>&1
)
$scanExit = $LASTEXITCODE
$scanOutput | Out-File -LiteralPath $logPath -Encoding utf8
$scanText = ($scanOutput | Out-String)
$match = [regex]::Match($scanText, 'scanned .*\((?<bytes>[0-9][0-9,]*) bytes\)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
if (-not $match.Success) {
    $match = [regex]::Match($scanText, 'scanned[^0-9]*(?<bytes>[0-9][0-9,]*) bytes', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
if (-not $match.Success) { throw "Gitleaks did not report scanned bytes; see $logPath" }
$scannedBytes = [int64]($match.Groups['bytes'].Value -replace ',', '')
if ($scannedBytes -le 0) { throw "Gitleaks reported non-positive scanned bytes: $scannedBytes" }
if ($scanExit -ne 0) { throw "Gitleaks found secrets or failed with exit code $scanExit." }

[pscustomobject]@{
    Status = 'ok'
    Package = $package
    PackageBytes = $packageInfo.Length
    ExtractedBytes = [int64](($files | Measure-Object -Property Length -Sum).Sum)
    ScannedBytes = $scannedBytes
    GitleaksReport = $reportPath
} | ConvertTo-Json -Compress
