{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  # Version and hash live in hashes.json so update.sh can rewrite them.
  sources = lib.importJSON ./hashes.json;
  inherit (sources) version hashes;
in
stdenvNoCC.mkDerivation {
  pname = "nullclaw-chat-ui";
  inherit version;

  # The release archive already holds the static SvelteKit build; no Node here.
  src = fetchurl {
    url = "https://github.com/nullclaw/nullclaw-chat-ui/releases/download/v${version}/nullclaw-chat-ui-v${version}.tar.gz";
    hash = hashes."tar.gz";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share"
    cp -r build "$out/share/nullclaw-chat-ui"
    runHook postInstall
  '';

  meta = {
    description = "Web chat UI for NullClaw's WebSocket channel (static files)";
    homepage = "https://github.com/nullclaw/nullclaw-chat-ui";
    # Upstream declares no license (no LICENSE file, "license": null in
    # package.json), so none is claimed here.
    platforms = lib.platforms.all;
  };
}
