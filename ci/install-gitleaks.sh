#!/usr/bin/env bash
set -euo pipefail

version="${GITLEAKS_VERSION:?GITLEAKS_VERSION must be set}"
destination="${1:?destination path is required}"
case "$version" in
  (*[!0-9.]*|'') echo "Invalid gitleaks version: $version" >&2; exit 2 ;;
esac
archive="gitleaks_${version}_linux_x64.tar.gz"
checksums="gitleaks_${version}_checksums.txt"
base="https://github.com/gitleaks/gitleaks/releases/download/v${version}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl --fail --location --silent --show-error "$base/$archive" --output "$tmp/$archive"
curl --fail --location --silent --show-error "$base/$checksums" --output "$tmp/$checksums"
expected="$(awk -v name="$archive" '$NF == name || $NF == "*" name { print; count++ } END { if (count != 1) exit 1 }' "$tmp/$checksums")"
(
    cd "$tmp"
    printf '%s\n' "$expected" | sha256sum --check --status
)
mkdir -p "$(dirname "$destination")"
tar -xzf "$tmp/$archive" -C "$tmp"
install -m 0755 "$tmp/gitleaks" "$destination"
"$destination" version >/dev/null
