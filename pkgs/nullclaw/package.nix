{
  lib,
  stdenvNoCC,
  fetchurl,
  nightly ? false, # true: upstream's rolling `nightly` prerelease
}:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them without touching Nix code. The nightly has its own, bumped daily.
  sources = lib.importJSON (if nightly then ../nullclaw-nightly/hashes.json else ./hashes.json);
  inherit (sources) version hashes;

  targets = {
    "aarch64-darwin" = "macos-aarch64";
    "aarch64-linux" = "linux-aarch64";
    "x86_64-linux" = "linux-x86_64";
  };

  system = stdenvNoCC.hostPlatform.system;
  target = targets.${system} or (throw "NullClaw has no prebuilt release for ${system}");
  # Tagged releases name their assets nullclaw-<target>.bin; the nightly drops the suffix.
  tag = if nightly then "nightly" else "v${version}";
  asset = if nightly then "nullclaw-${target}" else "nullclaw-${target}.bin";
in
stdenvNoCC.mkDerivation {
  pname = if nightly then "nullclaw-nightly" else "nullclaw";
  inherit version;

  src = fetchurl {
    url = "https://github.com/nullclaw/nullclaw/releases/download/${tag}/${asset}";
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
