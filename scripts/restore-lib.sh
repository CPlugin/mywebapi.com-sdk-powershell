#!/usr/bin/env bash
# Restore Microsoft.AspNetCore.SignalR.Client (+deps) into src/MyWebApi/lib.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/src/MyWebApi/lib"
OUT="$ROOT/build/RealtimeLib/bin/publish"
rm -rf "$LIB" "$OUT"; mkdir -p "$LIB"
dotnet publish "$ROOT/build/RealtimeLib/RealtimeLib.csproj" -c Release -o "$OUT"
# Copy only the SignalR/runtime managed assemblies the module needs at runtime.
for dll in "$OUT"/Microsoft.AspNetCore.* "$OUT"/Microsoft.Extensions.* "$OUT"/System.Threading.Channels.dll "$OUT"/Microsoft.AspNetCore.SignalR.Client.Core.dll; do
    [ -f "$dll" ] && cp "$dll" "$LIB/" || true
done
echo "Restored $(ls -1 "$LIB" | wc -l) assemblies into $LIB"
