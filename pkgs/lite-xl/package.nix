{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

let
  # Version and hash live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
in
stdenvNoCC.mkDerivation {
  pname = "lite-xl";
  inherit version;

  # Upstream's "addons" release: the same core as nixpkgs' lite-xl plus ~100
  # pure-Lua language plugins (Nix, Go, Rust, TOML, YAML, ...) and ~50 colour
  # schemes. Unlike nixpkgs' build it is a real Lite XL.app bundle.
  src = fetchurl {
    url = "https://github.com/lite-xl/lite-xl/releases/download/v${version}/lite-xl-v${version}-addons-macos-arm64.dmg";
    hash = hashes."macos-arm64.dmg";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  # The bundle is ad-hoc signed upstream; stripping or patching would break it.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications" "$out/bin"
    cp -R "Lite XL.app" "$out/Applications/"
    # Exec the bundle's binary by full path: it finds its data dir relative to
    # itself, which a plain symlink in bin/ could break.
    cat > "$out/bin/lite-xl" <<SH
    #!/bin/sh
    exec "$out/Applications/Lite XL.app/Contents/MacOS/lite-xl" "\$@"
    SH
    chmod +x "$out/bin/lite-xl"
    runHook postInstall
  '';

  meta = {
    description = "Lightweight text editor written in Lua, upstream addons build (Lite XL.app)";
    homepage = "https://lite-xl.com/";
    license = lib.licenses.mit;
    mainProgram = "lite-xl";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
