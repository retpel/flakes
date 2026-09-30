#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

latest="$(gh release view -R 1mcp-app/agent --json tagName -q .tagName)"
version="${latest#v}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "1mcp: $current is latest"; exit 0; }

declare -A assets=(
  [aarch64-darwin]=darwin-arm64
  [aarch64-linux]=linux-arm64
  [x86_64-linux]=linux-x64
)

hashes='{}'
for system in "${!assets[@]}"; do
  hash="$(nix store prefetch-file --json \
    "https://github.com/1mcp-app/agent/releases/download/v$version/1mcp-${assets[$system]}.tar.gz" | jq -r .hash)"
  hashes="$(jq --arg s "$system" --arg h "$hash" '. + {($s): $h}' <<<"$hashes")"
done

jq -n --arg v "$version" --argjson h "$hashes" '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
echo "1mcp: $current -> $version"
