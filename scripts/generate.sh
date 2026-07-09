#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Wipe previously generated cmdlets so removed operations don't linger.
rm -rf "$ROOT/src/MyWebApi/Public/MT4" "$ROOT/src/MyWebApi/Public/MT5"
dotnet run --project "$ROOT/build/GenerateCmdlets/GenerateCmdlets.csproj" -- \
    "$ROOT/spec/v2.json" "$ROOT/src/MyWebApi"
