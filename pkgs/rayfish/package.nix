{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, glibc, libgcc }:

let
  # Version and per-system hashes live in hashes.json so update.sh can rewrite
  # them without touching Nix code.
  versionData = lib.importJSON ./hashes.json;
  inherit (versionData) version hashes;

  assets = {
    "aarch64-darwin" = "ray-macos-aarch64";
    "aarch64-linux" = "ray-linux-aarch64";
    "x86_64-linux" = "ray-linux-x86_64";
  };

  system = stdenvNoCC.hostPlatform.system;
  isLinux = stdenvNoCC.hostPlatform.isLinux;
  asset = assets.${system} or (throw "Rayfish has no prebuilt release for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "rayfish";
  inherit version;

  src = fetchurl {
    url = "https://github.com/rayfish/rayfish/releases/download/v${version}/${asset}";
    hash = hashes.${system};
  };

  dontUnpack = true;
  dontFixup = !isLinux;

  nativeBuildInputs = lib.optional isLinux autoPatchelfHook;
  buildInputs = lib.optionals isLinux [ glibc libgcc ];
  runtimeDependencies = lib.optionals isLinux [ libgcc ];

  installPhase = ''
    install -Dm755 "$src" "$out/libexec/rayfish/ray"
    install -Dm755 ${./ray-guard.sh} "$out/bin/ray"
    substituteInPlace "$out/bin/ray" \
      --replace-fail '@REAL@' "$out/libexec/rayfish/ray"
  '';

  meta = {
    description = "P2P mesh VPN powered by iroh";
    homepage = "https://rayfish.xyz";
    license = lib.licenses.mpl20;
    mainProgram = "ray";
    platforms = builtins.attrNames hashes;
  };
}
