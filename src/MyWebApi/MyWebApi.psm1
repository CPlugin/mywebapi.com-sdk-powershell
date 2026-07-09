#Requires -Version 7.4
Set-StrictMode -Version Latest

# * Load bundled managed assemblies (SignalR client + deps) if present.
#   lib/ is populated by scripts/restore-lib.sh; absent during a bare REST-only import.
$libPath = Join-Path $PSScriptRoot 'lib'
if (Test-Path $libPath) {
    foreach ($dll in Get-ChildItem -Path $libPath -Filter '*.dll' -ErrorAction SilentlyContinue) {
        try { Add-Type -Path $dll.FullName -ErrorAction Stop } catch { <# already loaded / incompatible #> }
    }
}

# * Dot-source classes first (types other files depend on), then private helpers, then public cmdlets.
foreach ($folder in 'Classes', 'Private', 'Public') {
    $root = Join-Path $PSScriptRoot $folder
    if (Test-Path $root) {
        foreach ($file in Get-ChildItem -Path $root -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue) {
            . $file.FullName
        }
    }
}
