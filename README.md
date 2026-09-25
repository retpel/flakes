# flakes

Nix packages by `Prompter`.

> [!WARNING]
> **DYOR (Do Your Own Research).** These packages are written largely with AI
> agents and provided as-is, without warranty. Upstream binaries are fetched
> from their official release pages and pinned by hash, but that only proves
> the download is unchanged, not that the program is safe. Read the package
> definition and the upstream project before installing, especially anything
> that runs as a system service or with root privileges.

## Packages

| Package | Description |
|---|---|
| [rayfish](pkgs/rayfish) | P2P mesh VPN (iroh), with a nix-darwin/NixOS service module |

## Usage

```nix
{
  inputs.retpel.url = "github:retpel/flakes";
  inputs.retpel.inputs.nixpkgs.follows = "nixpkgs";

  # Either take packages straight from the flake (pinned nixpkgs) ...
  environment.systemPackages = [ inputs.retpel.packages.${system}.rayfish ];

  # ... or build them against your own nixpkgs through the overlay.
  nixpkgs.overlays = [ inputs.retpel.overlays.default ];
  environment.systemPackages = [ pkgs.retpel.rayfish ];

  # Packages with a service module:
  modules = [ inputs.retpel.darwinModules.rayfish ];  # or nixosModules
}
```

Or run one without installing: `nix run github:retpel/flakes#rayfish -- --version`.

## Outputs

- `packages.<system>.<name>`: only packages that build on `<system>`
- `overlays.default`: adds `pkgs.retpel.<name>`
- `darwinModules.<name>`, `nixosModules.<name>`: for packages that have a `module.nix`
- `checks.<system>.<name>`: builds every package
- `formatter`: `nixfmt-rfc-style`

Systems: `aarch64-darwin`, `aarch64-linux`, `x86_64-linux`.

## Updates

`.github/workflows/update.yml` runs daily. For each `pkgs/<name>/update.sh`, it
runs the script. If files changed, it builds the package and commits
`Update <name> to vX.Y.Z` to `main`. Run it from the Actions tab to update a
single package.

## License

Each packaged program keeps its own license, set by its authors and listed in
its `meta.license`. All product names, logos and trademarks belong to their
respective owners and creators. This repository is not affiliated with or
endorsed by them.
