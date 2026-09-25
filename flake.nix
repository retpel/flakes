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

      # Every directory under pkgs/ is a package: pkgs/<name>/package.nix.
      pkgDirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./pkgs);
      packageNames = builtins.attrNames pkgDirs;

      # Some packages here are unfree upstream binaries; allow only our own.
      pkgsFor = eachSystem (system: import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) packageNames;
      });

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

      # Service modules, by file name in pkgs/<name>/: module.nix is exported for
      # both nix-darwin and NixOS, darwin-module.nix / nixos-module.nix for one.
      modulesFrom = file:
        lib.genAttrs (builtins.filter (name: builtins.pathExists ./pkgs/${name}/${file}) packageNames) (
          name: import ./pkgs/${name}/${file} self
        );
    in
    {
      packages = eachSystem (system: lib.filterAttrs (_: available system) (mkPackagesFor pkgsFor.${system}));

      overlays.default = import ./overlays { inherit mkPackagesFor; };

      darwinModules = modulesFrom "module.nix" // modulesFrom "darwin-module.nix";
      nixosModules = modulesFrom "module.nix" // modulesFrom "nixos-module.nix";

      checks = self.packages;

      formatter = eachSystem (system: pkgsFor.${system}.nixfmt-rfc-style);
    };
}
