#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

latest="$(gh release view -R lite-xl/lite-xl --json tagName -q .tagName)"
version="${latest#v}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "lite-xl: $current is latest"; exit 0; }

hash="$(nix store prefetch-file --json \
  "https://github.com/lite-xl/lite-xl/releases/download/v$version/lite-xl-v$version-addons-macos-arm64.dmg" | jq -r .hash)"

jq -n --arg v "$version" --arg h "$hash" '{version: $v, hashes: {"macos-arm64.dmg": $h}}' > hashes.json
echo "lite-xl: $current -> $version"
