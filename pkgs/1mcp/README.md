# 1mcp

A Nix package and NixOS service module for [1MCP](https://docs.1mcp.app), a
runtime that aggregates MCP servers behind one HTTP endpoint (`/mcp`).

The package uses upstream's prebuilt release (a Node.js single executable
application) and does not build 1MCP locally. The pinned release (`version` in
`hashes.json`) has SHA-256 checksums for:

- Apple Silicon macOS (`aarch64-darwin`)
- ARM64 Linux (`aarch64-linux`)
- x86_64 Linux (`x86_64-linux`)

On Linux the binary is patched with `autoPatchelfHook` (glibc, libgcc,
libstdc++) so it runs on NixOS; the embedded app survives the patch. It is
never stripped.

The attribute name starts with a digit, so quote it:
`inputs.retpel.packages.${system}."1mcp"`, `pkgs.retpel."1mcp"`,
`services."1mcp"`. `nix run github:retpel/flakes#1mcp` needs no quotes.

## Usage (NixOS)

```nix
{
  imports = [ inputs.retpel.nixosModules."1mcp" ];

  services."1mcp" = {
    enable = true;
    user = "alice";
    externalUrl = "https://host.example:3050"; # behind a TLS proxy
  };
}
```

## Options

| Option | Default | Description |
|---|---|---|
| `enable` | `false` | Run `1mcp serve` as a systemd service. |
| `package` | this flake's package | 1MCP package to run. |
| `user` | (required) | User the runtime and its MCP servers run as, with that user's PATH (so `npx`/`uvx` servers work). |
| `configDir` | `~<user>/.config/1mcp` | Config directory. `mcp.json` is created empty on first start and never overwritten, so edit it in place. |
| `host` | `127.0.0.1` | Listen address. Keep it on loopback and put a TLS proxy in front. |
| `port` | `3050` | HTTP port. |
| `externalUrl` | `null` | Public base URL for OAuth callbacks and advertised URLs. |
| `enableAuth` | `true` | OAuth 2.1 on `/mcp` (`--enable-auth`). |
| `environmentFile` | `<configDir>/.env` | Optional `KEY=value` file (API keys for MCP servers); skipped when missing. |
| `extraArgs` | `[ ]` | Extra `1mcp serve` flags, e.g. `--enable-config-reload`, `--trust-proxy loopback`. |

## Updates

`update.sh` checks the latest upstream release and rewrites `hashes.json`.
Consumers pick it up with `nix flake update retpel`.

## Outputs

- `packages.<system>."1mcp"`
- `pkgs.retpel."1mcp"` through `overlays.default`
- `nixosModules."1mcp"`
