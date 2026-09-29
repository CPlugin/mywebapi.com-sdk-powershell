#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE="$ROOT/src/MyWebApi"

# Generate into a scratch tree first and swap only on success: a failed generator run (for
# example a missing pinned SDK) must not leave the module with its cmdlets wiped.
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/mywebapi-gen.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

dotnet run --project "$ROOT/build/GenerateCmdlets/GenerateCmdlets.csproj" -- \
    "$ROOT/spec/v2.json" "$STAGE"

# Replace the previously generated cmdlets wholesale so removed operations don't linger.
rm -rf "$MODULE/Public/MT4" "$MODULE/Public/MT5"
mkdir -p "$MODULE/Public"
for platform in MT4 MT5; do
    if [ -d "$STAGE/Public/$platform" ]; then
        mv "$STAGE/Public/$platform" "$MODULE/Public/$platform"
    fi
done
mv "$STAGE/generated-exports.psd1" "$MODULE/generated-exports.psd1"
