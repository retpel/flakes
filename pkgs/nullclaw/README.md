# nullclaw

A Nix package for [NullClaw](https://github.com/nullclaw/nullclaw), a small,
fully autonomous AI assistant shipped as one static Zig binary. Two packages
share this `package.nix`:

- `nullclaw`: the latest tagged release (`version` in `hashes.json`).
- `nullclaw-nightly`: upstream's rolling `nightly` prerelease
  (`version` in `../nullclaw-nightly/hashes.json`, as `YYYYMMDD-<commit>`).

Both use upstream prebuilt release binaries and do not compile NullClaw
locally. They have SHA-256 checksums for:

- Apple Silicon macOS (`aarch64-darwin`)
- ARM64 Linux (`aarch64-linux`)
- x86_64 Linux (`x86_64-linux`)

The Linux binaries are statically linked against musl, so they run on NixOS
without patching. Both packages install `bin/nullclaw`; install one of them.

## Usage

```nix
{
  inputs.retpel.url = "github:retpel/flakes";
  inputs.retpel.inputs.nixpkgs.follows = "nixpkgs";

  environment.systemPackages = [ inputs.retpel.packages.${system}.nullclaw ];
  # or: inputs.retpel.packages.${system}.nullclaw-nightly
}
```

Through the overlay: `pkgs.retpel.nullclaw`, `pkgs.retpel.nullclaw-nightly`.

Or run it without installing:

```sh
nix run github:retpel/flakes#nullclaw -- --version
nix run github:retpel/flakes#nullclaw-nightly -- --version
```

Configuration lives in `~/.nullclaw`, as upstream documents; start with
`nullclaw onboard`.

## Nightly

Upstream rebuilds the `nightly` release in place: every day it replaces the
assets under the same file names. The pinned hashes therefore go stale as soon
as upstream publishes (its build starts at 02:23 UTC) and stay stale until this repo's daily
update (03:00 UTC) commits the new ones.

While they are stale, a build that has to download the binary fails with a
hash mismatch. A binary already in your Nix store keeps working. So run
`nix flake update retpel` before rebuilding, and use `nullclaw` if you need
builds of an older lock to keep working.

## Updating and services

- `nullclaw update` detects the Nix store path and only prints instructions
  (for nixpkgs, not this flake). Upgrade with `nix flake update retpel`.
- `nullclaw service install` writes a user service (systemd on Linux, a
  LaunchAgent on macOS) that points at the current `/nix/store` path. After an
  upgrade it keeps running the old version until you run
  `nullclaw service install` again, and it breaks once that path is
  garbage-collected. This flake has no service module for it.

## Updates

Each package has an `update.sh`, run by the repo's daily workflow:

- `nullclaw/update.sh` bumps to the latest upstream release.
- `nullclaw-nightly/update.sh` reads the nightly's version from its release
  notes and its hashes from the per-asset `.sha256` files. It exits cleanly
  when upstream is mid-upload.

The workflow checks the flake after an update and commits to `main`.
Consumers pick it up with `nix flake update retpel`.

## Outputs

- `packages.<system>.nullclaw`, `packages.<system>.nullclaw-nightly`
- `pkgs.retpel.nullclaw`, `pkgs.retpel.nullclaw-nightly` through `overlays.default`
