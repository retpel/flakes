{ lib, stdenvNoCC, fetchurl }:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them without touching Nix code.
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version hashes;

  assets = {
    "aarch64-darwin" = "nullclaw-macos-aarch64.bin";
    "aarch64-linux" = "nullclaw-linux-aarch64.bin";
    "x86_64-linux" = "nullclaw-linux-x86_64.bin";
  };

  system = stdenvNoCC.hostPlatform.system;
  asset = assets.${system} or (throw "NullClaw has no prebuilt release for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "nullclaw";
  inherit version;

  src = fetchurl {
    url = "https://github.com/nullclaw/nullclaw/releases/download/v${version}/${asset}";
    hash = hashes.${system};
  };

  # Upstream ships stripped binaries: static musl on Linux, signed on macOS.
  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    install -Dm755 "$src" "$out/bin/nullclaw"
  '';

  meta = {
    description = "Small, fully autonomous AI assistant infrastructure written in Zig";
    homepage = "https://github.com/nullclaw/nullclaw";
    license = lib.licenses.mit;
    mainProgram = "nullclaw";
    platforms = builtins.attrNames hashes;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
