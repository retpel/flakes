{
  description = "Nix packages by Prompter";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      eachSystem = lib.genAttrs systems;
      pkgsFor = eachSystem (system: import nixpkgs { inherit system; });

      # Every directory under pkgs/ is a package: pkgs/<name>/package.nix.
      pkgDirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./pkgs);
      packageNames = builtins.attrNames pkgDirs;

      # Packages that also ship a service module: pkgs/<name>/module.nix.
      moduleNames = builtins.filter (name: builtins.pathExists ./pkgs/${name}/module.nix) packageNames;

      # All packages built against `pkgs`, in one scope so they can depend on
      # each other by argument name.
      mkPackagesFor = pkgs:
        let
          scope = lib.makeScope pkgs.newScope (
            self: lib.genAttrs packageNames (name: self.callPackage ./pkgs/${name}/package.nix { })
          );
        in
        lib.genAttrs packageNames (name: scope.${name});

      # Only expose packages that build on the given system.
      available = system: pkg:
        lib.meta.availableOn pkgsFor.${system}.stdenv.hostPlatform pkg && !(pkg.meta.broken or false);

      modules = lib.genAttrs moduleNames (name: import ./pkgs/${name}/module.nix self);
    in
    {
      packages = eachSystem (system: lib.filterAttrs (_: available system) (mkPackagesFor pkgsFor.${system}));

      overlays.default = import ./overlays { inherit mkPackagesFor; };

      darwinModules = modules;
      nixosModules = modules;

      checks = self.packages;

      formatter = eachSystem (system: pkgsFor.${system}.nixfmt-rfc-style);
    };
}
