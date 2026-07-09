# Rebuilds FunctionsToExport in the manifest from the actual .ps1 files under Public/.
param(
    [string] $ModuleRoot = "$PSScriptRoot/../src/MyWebApi"
)
$funcs = Get-ChildItem "$ModuleRoot/Public" -Recurse -Filter *.ps1 |
    ForEach-Object { $_.BaseName } | Sort-Object -Unique

$manifestPath = Join-Path $ModuleRoot 'MyWebApi.psd1'
$content = Get-Content $manifestPath -Raw
$list = "@(`n" + (($funcs | ForEach-Object { "        '$_'" }) -join ",`n") + "`n    )"
$updated = [regex]::Replace($content, "FunctionsToExport\s*=\s*@\([^)]*\)", "FunctionsToExport = $list", 'Singleline')
Set-Content $manifestPath $updated -NoNewline
Write-Host "FunctionsToExport now lists $($funcs.Count) functions."
