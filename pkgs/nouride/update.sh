#!/usr/bin/env bash
# Bump hashes.json to the latest upstream release (or $TAG), for both editions.
# Hashes come from the release's SHA256SUMS files, so nothing is downloaded.
# Needs gh, curl, jq and nix.
set -euo pipefail
cd "$(dirname "$0")"

repo=nouverse/nouride-releases
tag="${TAG:-$(gh release view -R "$repo" --json tagName -q .tagName)}"
version="${tag#v}"
current="$(jq -r .version hashes.json)"
[ "$version" != "$current" ] || { echo "nouride: $current is latest"; exit 0; }

base="https://github.com/$repo/releases/download/$tag"
sums="$(curl -fsSL "$base/SHA256SUMS"; curl -fsSL "$base/SHA256SUMS-router")"

hashes='{}'
for name in nouride-linux-x64 nouride-linux-arm64 nouride-router-linux-x64 nouride-router-linux-arm64; do
  # File names may carry a "./" (since v0.5.14) or "*" (binary mode) prefix.
  hex="$(awk -v f="$name.tar.gz" '{ n = $2; sub(/^\*/, "", n); sub(/^\.\//, "", n) } n == f { print $1 }' <<<"$sums")"
  [ -n "$hex" ] || { echo "nouride: no checksum for $name in $tag" >&2; exit 1; }
  sri="$(nix hash convert --hash-algo sha256 --to sri "$hex")"
  hashes="$(jq --arg k "$name" --arg v "$sri" '. + {($k): $v}' <<<"$hashes")"
done

jq -n --arg v "$version" --argjson h "$hashes" '{version: $v, hashes: $h}' > hashes.json
echo "nouride: $current -> $version"
