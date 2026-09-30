#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
# Releases are tagged releases/<version> on obdev/littlesnitch-linux (the open
# source parts); the binaries themselves are downloaded from obdev.at.
set -euo pipefail
cd "$(dirname "$0")"

latest="$(gh release view -R obdev/littlesnitch-linux --json tagName -q .tagName)"
version="${latest#releases/}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "littlesnitch: $current is latest"; exit 0; }

declare -A arches=(
  [aarch64-linux]=arm64
  [x86_64-linux]=amd64
)

hashes='{}'
for system in "${!arches[@]}"; do
  hash="$(nix store prefetch-file --json \
    "https://obdev.at/downloads/littlesnitch-linux/littlesnitch-$version-${arches[$system]}-linux-musl.tar.gz" | jq -r .hash)"
  hashes="$(jq --arg s "$system" --arg h "$hash" '. + {($s): $h}' <<<"$hashes")"
done

jq -n --arg v "$version" --argjson h "$hashes" '{version: $v, hashes: ($h | to_entries | sort_by(.key) | from_entries)}' > hashes.json
echo "littlesnitch: $current -> $version"
