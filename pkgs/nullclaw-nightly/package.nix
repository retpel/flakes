# Upstream's rolling nightly prerelease. Same package as pkgs/nullclaw; only the
# release and hashes.json (here, bumped daily by update.sh) differ.
{ nullclaw }:

nullclaw.override { nightly = true; }
