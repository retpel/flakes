#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release. Needs gh, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

latest="$(gh release view -R nullclaw/nullclaw-chat-ui --json tagName -q .tagName)"
version="${latest#v}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "nullclaw-chat-ui: $current is latest"; exit 0; }

hash="$(nix store prefetch-file --json \
  "https://github.com/nullclaw/nullclaw-chat-ui/releases/download/v$version/nullclaw-chat-ui-v$version.tar.gz" | jq -r .hash)"

jq -n --arg v "$version" --arg h "$hash" '{version: $v, hashes: {"tar.gz": $h}}' > hashes.json
echo "nullclaw-chat-ui: $current -> $version"
