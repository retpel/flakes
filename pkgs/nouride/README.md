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
| `services.nouride.environment` | `{ }` | Extra environment variables. |
| `services.nouride.environmentFile` | `null` | `KEY=value` secrets file kept out of the store. |
| `services.nouride.extraPackages` | bash, coreutils, findutils, gnugrep, gnused, curl, git | Commands available to agents on the daemon's `PATH`. |

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

## Updates

`update.sh` reads the latest release's `SHA256SUMS` and `SHA256SUMS-router`
and rewrites `hashes.json` (set `TAG=vX.Y.Z` for a specific release). The
repo's daily workflow runs it.
