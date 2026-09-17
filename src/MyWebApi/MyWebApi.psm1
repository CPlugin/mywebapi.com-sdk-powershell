#Requires -Version 7.4
Set-StrictMode -Version Latest

# * Load bundled managed assemblies (SignalR client + deps) if present. These enable the
#   OPTIONAL real-time layer only (Connect-MT4Realtime/Connect-MT5Realtime and friends) --
#   the REST surface (all the Get-/New-/Set-/Remove- cmdlets) works fully without them.
#   lib/ is populated by scripts/restore-lib.sh; absent during a bare REST-only import.
$libPath = Join-Path $PSScriptRoot 'lib'
if (Test-Path $libPath) {
    $assemblyErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($dll in Get-ChildItem -Path $libPath -Filter '*.dll' -ErrorAction Stop) {
        try {
            Add-Type -Path $dll.FullName -ErrorAction Stop
        } catch {
            $assemblyErrors.Add(("{0}: {1}" -f $dll.Name, $_.Exception.Message))
        }
    }
    if ($assemblyErrors.Count -gt 0) {
        throw ("MyWebApi real-time assemblies are incompatible with PowerShell 7.4/.NET 8: {0}" -f ($assemblyErrors -join '; '))
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
