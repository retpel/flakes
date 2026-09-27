# AGENTS.md

Guidance for coding agents working in this repo. `README.md` is the user-facing
doc; keep it and each package's README in sync with behavior. Remote:
`retpel/flakes`.

## Layout

| Path | Role |
|---|---|
| `flake.nix` | Discovers `pkgs/*/package.nix` and the module files; builds all packages in one `makeScope` so they can depend on each other by argument name; filters `packages.<system>` with `lib.meta.availableOn`. |
| `overlays/default.nix` | `pkgs.retpel.<name>`, built against the consumer's nixpkgs. |
| `pkgs/<name>/package.nix` | The derivation. Read `version`/hashes from `hashes.json` for prebuilt binaries. |
| `pkgs/<name>/hashes.json` | `{ "version": ..., "hashes": { "<key>": "sha256-..." } }`, written by `update.sh`. Keys are whatever the package looks up: the system for rayfish and nullclaw. |
| `pkgs/<name>/update.sh` | Optional. Bumps `hashes.json` to the latest upstream; no-op when current. Run by `.github/workflows/update.yml`. |
| `pkgs/<name>/module.nix` | Optional. `self: { config, ... }: { ... }`; exported as both `darwinModules.<name>` and `nixosModules.<name>`. Default package is `self.packages.${system}.<name>`. |
| `pkgs/<name>/nixos-module.nix`, `darwin-module.nix` | Same shape as `module.nix`, exported only to `nixosModules` or `darwinModules`. |
| `.github/workflows/check.yml` | `nix flake check` on Linux x86_64/aarch64 and macOS. |

## Adding a package

1. `pkgs/<name>/package.nix` (+ `hashes.json` and `update.sh` if it tracks upstream releases).
2. Set `meta.platforms` to the systems it really supports; that's what filters `packages.<system>`.
3. Add a row to the README package table and a `pkgs/<name>/README.md` if it has options.
4. `git add` new files; flakes ignore untracked files.

## Package notes

**nullclaw / nullclaw-nightly**: static prebuilt binaries (musl on Linux), so no
patchelf; keep `dontFixup`. `nullclaw-nightly` is `nullclaw.override { nightly = true; }`
with its own `pkgs/nullclaw-nightly/hashes.json`. Upstream's `nightly` release is
rebuilt in place under the same asset names, so its pinned hashes go stale each
day until `update.sh` runs; its `update.sh` exits 0 when the assets are mid-upload.
`module.nix` (both platforms, like rayfish) runs `nullclaw gateway` as `user` with
`NULLCLAW_HOME`, mirroring upstream's `service install` unit but always pointing at
`cfg.package`. Keep `enable` off by default and `user` required.

**rayfish**: see `pkgs/rayfish/README.md`. Services run `libexec/rayfish/ray`
directly, never the guarded `bin/ray`; don't loosen `ray-guard.sh`. Detect
nix-darwin in `module.nix` with `options ? launchd`, not `pkgs.stdenv`
(infinite recursion). The Darwin launchd job must keep waiting for the Nix
store before `exec`. `ray-fix` uses absolute system-tool paths because it runs
under `sudo`.

## Checking changes

```sh
nix flake check --all-systems --no-build   # evaluate everything
nix flake check                            # build this host's packages
nix build .#<name> && ./result/bin/<prog> --version
```

Only `aarch64-darwin` builds locally; Linux is exercised by CI. To test in the
system config, point the input in `/etc/nix-darwin` at this checkout and run
`nh darwin build`. Only run `nh darwin switch` when asked.

## Commits

Short imperative subject lines with no prefix. The update workflow commits as
`Update <name> to vX.Y.Z`.
