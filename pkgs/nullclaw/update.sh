#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

latest="$(gh release view -R nullclaw/nullclaw --json tagName -q .tagName)"
version="${latest#v}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "nullclaw: $current is latest"; exit 0; }

declare -A assets=(
  [aarch64-darwin]=nullclaw-macos-aarch64.bin
  [aarch64-linux]=nullclaw-linux-aarch64.bin
  [x86_64-linux]=nullclaw-linux-x86_64.bin
)

hashes='{}'
for system in "${!assets[@]}"; do
  hash="$(nix store prefetch-file --json \
    "https://github.com/nullclaw/nullclaw/releases/download/v$version/${assets[$system]}" | jq -r .hash)"
  hashes="$(jq --arg s "$system" --arg h "$hash" '. + {($s): $h}' <<<"$hashes")"
done

jq -n --arg v "$version" --argjson h "$hashes" '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
echo "nullclaw: $current -> $version"
