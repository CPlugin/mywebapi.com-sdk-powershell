#!/usr/bin/env bash
# Fetch the WebAPI v2 OpenAPI document into spec/v2.json.
# Usage: SPEC_URL=https://host/swagger/v2/swagger.json ./scripts/fetch-spec.sh
set -euo pipefail
SPEC_URL="${SPEC_URL:-http://localhost:5080/swagger/v2/swagger.json}"
DEST="$(dirname "$0")/../spec/v2.json"
echo "Fetching $SPEC_URL -> $DEST"
curl -fsSL "$SPEC_URL" -o "$DEST"
# Pretty-print for reviewable diffs.
tmp="$(mktemp)"
pwsh -NoProfile -Command "Get-Content '$DEST' -Raw | ConvertFrom-Json -Depth 100 | ConvertTo-Json -Depth 100" > "$tmp"
mv "$tmp" "$DEST"
echo "Wrote $(wc -c < "$DEST") bytes."
