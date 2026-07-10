#Requires -Version 7.4
Set-StrictMode -Version Latest

# * Load bundled managed assemblies (SignalR client + deps) if present. These enable the
#   OPTIONAL real-time layer only (Connect-MT4Realtime/Connect-MT5Realtime and friends) --
#   the REST surface (all the Get-/New-/Set-/Remove- cmdlets) works fully without them.
#   lib/ is populated by scripts/restore-lib.sh; absent during a bare REST-only import.
$libPath = Join-Path $PSScriptRoot 'lib'
if (Test-Path $libPath) {
    foreach ($dll in Get-ChildItem -Path $libPath -Filter '*.dll' -ErrorAction SilentlyContinue) {
        try {
            Add-Type -Path $dll.FullName -ErrorAction Stop
        } catch {
            # * Non-fatal: the assembly may already be loaded, or incompatible with the
            #   current platform (e.g. a Windows-only dependency under a non-Windows host).
            #   Realtime cmdlets will surface a clear error later if a required type is missing.
            Write-Verbose "Skipping assembly '$($dll.Name)': $($_.Exception.Message)"
        }
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
