#!/usr/bin/env bash
# Restore Microsoft.AspNetCore.SignalR.Client (+deps) into src/MyWebApi/lib.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/src/MyWebApi/lib"
OUT="$ROOT/build/RealtimeLib/bin/publish"
rm -rf "$LIB" "$OUT"; mkdir -p "$LIB"
dotnet publish "$ROOT/build/RealtimeLib/RealtimeLib.csproj" -c Release -o "$OUT"
# Copy the ENTIRE SignalR client dependency graph the module needs at runtime.
# * The earlier allow-list missed transitive deps (e.g. System.IO.Pipelines), which
#   compile fine (Add-Type ref) but fail at connect time with FileNotFoundException.
#   Copying every published managed assembly (CopyLocalLockFileAssemblies=true puts
#   the full graph here) is the robust fix; the empty RealtimeLib shim is excluded.
for dll in "$OUT"/*.dll; do
    base="$(basename "$dll")"
    [ "$base" = "RealtimeLib.dll" ] && continue
    cp "$dll" "$LIB/"
done
echo "Restored $(ls -1 "$LIB" | wc -l) assemblies into $LIB"
