{ mkPackagesFor }:
# Builds pkgs/ against the consumer's nixpkgs and puts it under `pkgs.retpel`.
# The flake's own `packages` use this repo's pinned nixpkgs instead.
final: _prev: {
  retpel = mkPackagesFor final;
}
