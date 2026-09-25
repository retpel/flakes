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
| `services.nouride.stateDir` | `/var/lib/nouride` | Working directory and `HOME`: `config.toml` and `.nouride/`. |
| `services.nouride.user` / `group` | `nouride` | Service account, created when left at the default. |
| `services.nouride.environment` | `{ }` | Extra environment variables. |
| `services.nouride.environmentFile` | `null` | `KEY=value` secrets file kept out of the store. |
| `services.nouride.extraPackages` | bash, coreutils, findutils, gnugrep, gnused, curl, git | Commands available to agents on the daemon's `PATH`. |

## Updates

`update.sh` reads the latest release's `SHA256SUMS` and `SHA256SUMS-router`
and rewrites `hashes.json` (set `TAG=vX.Y.Z` for a specific release). The
repo's daily workflow runs it.
