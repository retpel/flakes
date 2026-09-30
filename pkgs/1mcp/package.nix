{ lib, stdenv, stdenvNoCC, fetchurl, autoPatchelfHook, glibc, libgcc }:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them without touching Nix code.
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version hashes;

  assets = {
    "aarch64-darwin" = "darwin-arm64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-linux" = "linux-x64";
  };

  system = stdenvNoCC.hostPlatform.system;
  isLinux = stdenvNoCC.hostPlatform.isLinux;
  asset = assets.${system} or (throw "1MCP has no prebuilt release for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "1mcp";
  inherit version;

  # Upstream's release is a Node.js single executable application (SEA): the
  # app is embedded in the node ELF/Mach-O, so never strip it.
  src = fetchurl {
    url = "https://github.com/1mcp-app/agent/releases/download/v${version}/1mcp-${asset}.tar.gz";
    hash = hashes.${system};
  };

  sourceRoot = ".";
  dontStrip = true;
  dontFixup = !isLinux;

  nativeBuildInputs = lib.optional isLinux autoPatchelfHook;
  # Node needs libstdc++ (stdenv.cc.cc.lib), not just libgcc.
  buildInputs = lib.optionals isLinux [ glibc libgcc stdenv.cc.cc.lib ];

  installPhase = ''
    install -Dm755 "1mcp-${asset}" "$out/bin/1mcp"
  '';

  meta = {
    description = "Unified MCP runtime that aggregates MCP servers behind one endpoint";
    homepage = "https://docs.1mcp.app";
    license = lib.licenses.asl20;
    mainProgram = "1mcp";
    platforms = builtins.attrNames hashes;
  };
}
