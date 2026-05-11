{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,

  dbus,
  curl,
  libcap,
  nss,
  libpcap,
  glib,
  gtk3,
  libayatana-appindicator,
  libayatana-indicator,
  ayatana-ido,
  libdbusmenu,
  webkitgtk_4_1,
  libsoup_3,
  openjdk17,
  cliOnly ? true,
}:
let
  currentVersion = lib.importJSON ./version.json;
  downloadUrl =
    arch:
    "https://pkg.cloudflareclient.com/pool/noble/main/c/cloudflare-warp/cloudflare-warp_${currentVersion.version}_${arch}.deb";
  defaultArgs =
    {
      "x86_64-linux" = {
        src = fetchurl {
          url = downloadUrl "amd64";
          hash = currentVersion."hash-linux-x64";
        };
      };
      "aarch64-linux" = {
        src = fetchurl {
          url = downloadUrl "arm64";
          hash = currentVersion."hash-linux-arm64";
        };
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "cloudflare-warp-bin: Unsupported platform: ${stdenv.hostPlatform.system}");
  terminalMissing = [
    "libpcap.so.0.8"
    "libayatana-appindicator3.so.1"
    "libayatana-indicator3.so.7"
    "libayatana-ido3-0.4.so.0"
    "libdbusmenu-glib.so.4"
    "libwebkit2gtk-4.1.so.0"
    "libsoup-3.0.so.0"
    "libjavascriptcoregtk-4.1.so.0"
    "libjvm.so"
    "libcurl.so.4"
  ];
  fullMissing = [ "libpcap.so.0.8" ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "cloudflare-warp-bin";
  version = currentVersion.version;
  inherit (defaultArgs) src;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
  ];

  buildInputs = [
    dbus
    libcap
    nss
    libpcap
    glib
    gtk3
  ] ++ lib.optionals (!cliOnly) [
    curl
    libayatana-appindicator
    libayatana-indicator
    ayatana-ido
    libdbusmenu
    webkitgtk_4_1
    libsoup_3
    openjdk17
  ];

  dontBuild = true;
  dontConfigure = true;
  noDumpEnvVars = true;

  # libpcap.so.0.8 is Debian-specific versioning; nixpkgs ships libpcap.so.1
  # Keep terminal-only builds lightweight by ignoring non-essential optional runtime deps.
  # Full mode keeps complete runtime dependencies for GUI/plugin features.
  autoPatchelfIgnoreMissingDeps = if cliOnly then terminalMissing else fullMissing;
  autoPatchelfLibs = if (!cliOnly) then [ "${openjdk17}/lib/openjdk/lib/server" ] else [ ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  # Create a compat symlink for the Debian-specific libpcap.so.0.8
  # and add it to warp-dex's RPATH after autoPatchelfHook has finished
  postFixup = ''
    mkdir -p $out/lib
    ln -sf ${libpcap.lib}/lib/libpcap.so $out/lib/libpcap.so.0.8
    patchelf --add-rpath $out/lib $out/bin/warp-dex
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    cp -r usr/bin/* $out/bin/ || true
    cp -r usr/lib/* $out/lib/ || true
    # Also install the main binaries from /bin if present
    cp -r bin/* $out/bin/ 2>/dev/null || true

    # Install shell completions if bundled in the deb
    if [ -d usr/share/bash-completion ]; then
      mkdir -p $out/share/bash-completion
      cp -r usr/share/bash-completion/* $out/share/bash-completion/
    fi
    if [ -d usr/share/zsh ]; then
      mkdir -p $out/share/zsh
      cp -r usr/share/zsh/* $out/share/zsh/
    fi
    if [ -d usr/share/fish ]; then
      mkdir -p $out/share/fish
      cp -r usr/share/fish/* $out/share/fish/
    fi

    # Install desktop file if present
    if [ -d usr/share/applications ]; then
      mkdir -p $out/share/applications
      cp -r usr/share/applications/* $out/share/applications/
    fi

    # Install icons if present
    if [ -d usr/share/icons ]; then
      mkdir -p $out/share/icons
      cp -r usr/share/icons/* $out/share/icons/
    fi

    runHook postInstall
  '';

  meta = {
    description = "Cloudflare WARP client for Linux";
    homepage = "https://1.1.1.1";
    license = lib.licenses.unfreeRedistributable;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = "warp-cli";
  };
})
