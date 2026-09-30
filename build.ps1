#Requires -Version 7.4
[CmdletBinding()]
param([switch] $SkipLib)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$PSNativeCommandUseErrorActionPreference = $true

if (-not $SkipLib) { & "$root/scripts/restore-lib.sh" }
& "$root/scripts/generate.sh"
pwsh -NoProfile -NonInteractive -File "$root/scripts/update-manifest-exports.ps1"

Write-Host 'Validating manifest...' -ForegroundColor Cyan
Test-ModuleManifest "$root/src/MyWebApi/MyWebApi.psd1" | Out-Null

Write-Host 'Running PSScriptAnalyzer...' -ForegroundColor Cyan
$issues = Invoke-ScriptAnalyzer -Path "$root/src/MyWebApi" -Recurse -Settings "$root/PSScriptAnalyzerSettings.psd1"
if ($issues) { $issues | Format-Table -AutoSize; throw "PSScriptAnalyzer found $($issues.Count) issue(s)." }

Write-Host 'Running Pester...' -ForegroundColor Cyan
$cfg = New-PesterConfiguration
$cfg.Run.Path = "$root/tests"
$cfg.Run.PassThru = $true
$cfg.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $cfg
if ($null -eq $result -or $result.TotalCount -lt 1) { throw 'Pester discovered zero tests.' }
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) Pester test(s) failed." }
