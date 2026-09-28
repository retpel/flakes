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

## Service

`services.nullclaw` runs the gateway at boot, as `user`, restarting it when it
exits: the same as upstream's `nullclaw service install` (`nullclaw gateway`,
`NULLCLAW_HOME`, optional `.env`), but always the installed package. One
`module.nix` covers NixOS (systemd) and nix-darwin (launchd), exported as
`nixosModules.nullclaw` and `darwinModules.nullclaw`.

```nix
{
  imports = [ inputs.retpel.nixosModules.nullclaw ];  # or darwinModules.nullclaw

  services.nullclaw = {
    enable = true;
    user = "alice";
    # package = inputs.retpel.packages.${system}.nullclaw-nightly;
  };
}
```

The gateway runs an autonomous agent that can execute commands as `user`,
reachable from every configured channel. Review `autonomy` and each channel's
`allow_from` in `config.json` before enabling it.

| Option | Default | Description |
|---|---|---|
| `services.nullclaw.enable` | `false` | Run the gateway and put `nullclaw` on `PATH`. |
| `services.nullclaw.package` | `nullclaw` | Package to run; `nullclaw-nightly` works too. |
| `services.nullclaw.user` | (required) | User it runs as; must be declared in `users.users`. |
| `services.nullclaw.stateDir` | `<home>/.nullclaw` | `NULLCLAW_HOME`: `config.json`, `auth.json`, workspace. |
| `services.nullclaw.environmentFile` | `<stateDir>/.env` | `KEY=value` file for the gateway (e.g. API keys); skipped if missing. `null` disables it. |
| `services.nullclaw.watchdog.enable` | `false` | Restart the gateway when a polling channel gets stuck (see below). NixOS only. |
| `services.nullclaw.watchdog.interval` | `"5min"` | How often the watchdog checks. |
| `services.nullclaw.hardening.enable` | `false` | Filesystem read-only except `stateDir`, no privilege gain (see below). NixOS only. |
| `services.nullclaw.hardening.readWritePaths` | `[ ]` | Extra writable paths besides `stateDir`. |

Run `nullclaw onboard` as `user` first, so `stateDir` exists. After editing
`config.json`, restart the service: `nullclaw config reload` only validates.

- **NixOS:** systemd unit `nullclaw.service` (`Restart=always`), logs in the
  journal: `journalctl -u nullclaw`. Restart with `sudo systemctl restart nullclaw`.
- **macOS:** launchd daemon `com.nullclaw.gateway` running as `user`
  (`KeepAlive`), logging to `<stateDir>/gateway.log`. It waits for the Nix store
  at boot. Restart with `sudo launchctl kickstart -k system/com.nullclaw.gateway`.

### Watchdog

NullClaw restarts a stale channel thread itself (`<channel> issue: polling
thread stale`, then `Restarting <channel> (attempt N)`), but that restart first
joins the old thread. If the old thread is stuck in a request, the join never
returns: the process stays up, the channel stays dead, and `Restart=always`
never fires. Seen with Telegram in v2026.5.29.

Opt in with `watchdog.enable = true`. On NixOS the `nullclaw-watchdog` timer
then checks the log of the current run (`_SYSTEMD_INVOCATION_ID`) every
`watchdog.interval` and restarts `nullclaw.service` when it finds
` issue: polling thread stale`: the case that can hang. Restarting starts a
new run with a clean log, so it does not loop on the same warning. A single
` issue: health check failed` is left alone: it shows up for a transient
Telegram API error (seen during a long agent turn) and restarting then would
cut off the reply in progress.
Check what it did with `journalctl -u nullclaw-watchdog`.

### Hardening

NullClaw's own `security.sandbox` does not isolate anything on NixOS:
Landlock is still a stub upstream (`isAvailable()` returns false, and an
explicit `backend = "landlock"` silently falls back to no sandbox; see
nullclaw/nullclaw#882), and the firejail, bubblewrap and docker backends run
commands with no network, without `/nix/store`, or inside Alpine, which also
defeats an agent meant to look at the host. `nullclaw status` still says
"Sandbox: enabled".

With `hardening.enable = true`, systemd confines the gateway and every command
its agent runs instead: `ProtectSystem=strict` and `ProtectHome=read-only`
make the whole filesystem read-only except `stateDir` (plus
`hardening.readWritePaths`), `PrivateTmp`, `NoNewPrivileges` (setuid is
ignored, so `sudo` cannot work), and the kernel tunables, modules, logs,
cgroups, clock and hostname are protected. Network, processes (`/proc`) and
devices are left visible, so the agent can still monitor the machine; it just
cannot change files outside `stateDir`.

## Updating

- `nullclaw update` detects the Nix store path and only prints instructions
  (for nixpkgs, not this flake). Upgrade with `nix flake update retpel`.
- Don't use `nullclaw service install`: it writes a user service pointing at
  the current `/nix/store` path, which keeps running the old version after an
  upgrade and breaks once that path is garbage-collected. Use
  `services.nullclaw` instead.

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
- `nixosModules.nullclaw`, `darwinModules.nullclaw`: the `services.nullclaw` module
