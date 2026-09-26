# nouride

[Nouride](https://nouride.com), a lightweight multi-agent AI engine in a single
daemon, packaged from the upstream prebuilt release binaries
([nouverse/nouride-releases](https://github.com/nouverse/nouride-releases)).
**Linux only** (`x86_64-linux`, `aarch64-linux`), and **unfree**.

Two editions share one release and `hashes.json`:

- `nouride`: standard edition
- `nouride-router`: with the in-process Nougate AI Router (`pkgs/nouride-router`)

## NixOS

```nix
{
  inputs.retpel.url = "github:retpel/flakes";

  nixosConfigurations.<host> = nixpkgs.lib.nixosSystem {
    modules = [
      inputs.retpel.nixosModules.nouride
      {
        services.nouride.enable = true;
        # Router edition:
        # services.nouride.package = inputs.retpel.packages.x86_64-linux.nouride-router;
      }
    ];
  };
}
```

The module runs the daemon as a systemd service, like upstream's `install.sh`
does, but without the self-updater. The binary lives in the read-only store, so
upgrade by updating the flake input.

## Options

| Option | Default | Description |
|---|---|---|
| `services.nouride.enable` | `false` | Run the daemon and put `nouride` on `PATH`. |
| `services.nouride.package` | `nouride` | Build to run; use `nouride-router` for the Router edition. |
| `services.nouride.host` | `"127.0.0.1"` | Dashboard bind address. `0.0.0.0` exposes it. |
| `services.nouride.port` | `18254` | Dashboard / API port. |
| `services.nouride.routerPort` | `18256` | Nougate gateway port (Router edition; set `[nougate] port` to match). |
| `services.nouride.openFirewall` | `false` | Open the dashboard port, plus the Nougate port for the Router edition. |
| `services.nouride.user` | `"nouride"` | User the daemon runs as. See [Running as your own user](#running-as-your-own-user). |
| `services.nouride.group` | `nouride`, or that user's group | Group the daemon runs as. |
| `services.nouride.stateDir` | `/var/lib/nouride`, or that user's home | Working directory and `HOME`: `config.toml` and `.nouride/`. |
| `services.nouride.environment` | `{ }` | Extra environment variables (`TZ` defaults to `time.timeZone`). |
| `services.nouride.environmentFile` | `null` | `KEY=value` secrets file kept out of the store. |
| `services.nouride.extraPackages` | bash, coreutils, findutils, gnugrep, gnused, gawk, procps, util-linux, iproute2, which, curl, git | Commands available to agents on the daemon's `PATH` (systemd's `systemctl`/`journalctl` come with every NixOS service). |
| `services.nouride.privileged` | `false` | Drop the systemd sandbox so agents can manage the host. See [What agents can do on the host](#what-agents-can-do-on-the-host). |

## Running as your own user

By default the daemon runs as an isolated `nouride` system user, with its state
in `/var/lib/nouride`. Agents run commands on the host, so this keeps them away
from your files. The `nouride` CLI finds its daemon through the directory it
runs from, so manage it with
`sudo -u nouride sh -c 'cd /var/lib/nouride && nouride status'`.

To run it as an existing account instead, set that account in the host's
config:

```nix
services.nouride.user = "alice";
```

The daemon then runs as `alice`, with its state in `~alice/.nouride`, and
`nouride status` works for `alice` from `~`. Agents get that user's access to
the machine.

## What agents can do on the host

Agents run commands through `exec` (and the interactive `session` tool, which
needs `script` from util-linux), limited to what is on the service's `PATH`
and to what the sandbox allows.

**Commands.** `extraPackages` covers inspecting the host (`ps`, `free`,
`uptime`, `ip`, `ss`, `lsblk`, `systemctl`, `journalctl`). Some built-in skills
need more; `nouride doctor` names what is missing:

```nix
services.nouride.extraPackages = options.services.nouride.extraPackages.default ++ (with pkgs; [
  poppler-utils pandoc python3   # document-reading (plus libreoffice for Office files)
  tectonic                       # document-authoring
]);
```

**Sandbox.** By default the unit carries the hardening of upstream's generated
unit: the system is read-only, the home is read-only except `stateDir`, and
`sudo` cannot gain privileges. That is enough to report on the host, but not to
change it. `services.nouride.privileged = true` drops the sandbox, like
`nouride service install --privileged`, and puts `sudo` on `PATH`. The agent
then manages the host as far as the user's sudo rules allow, gated only by
nouride's exec policy (`nouride policy`). Use it only on a machine dedicated to
the daemon.

## Updates

`update.sh` reads the latest release's `SHA256SUMS` and `SHA256SUMS-router`
and rewrites `hashes.json` (set `TAG=vX.Y.Z` for a specific release). The
repo's daily workflow runs it.
