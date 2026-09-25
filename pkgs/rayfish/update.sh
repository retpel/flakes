#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

latest="$(gh release view -R rayfish/rayfish --json tagName -q .tagName)"
version="${latest#v}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "rayfish: $current is latest"; exit 0; }

declare -A assets=(
  [aarch64-darwin]=ray-macos-aarch64
  [aarch64-linux]=ray-linux-aarch64
  [x86_64-linux]=ray-linux-x86_64
)

hashes='{}'
for system in "${!assets[@]}"; do
  hash="$(nix store prefetch-file --json \
    "https://github.com/rayfish/rayfish/releases/download/v$version/${assets[$system]}" | jq -r .hash)"
  hashes="$(jq --arg s "$system" --arg h "$hash" '. + {($s): $h}' <<<"$hashes")"
done

jq -n --arg v "$version" --argjson h "$hashes" '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
echo "rayfish: $current -> $version"
