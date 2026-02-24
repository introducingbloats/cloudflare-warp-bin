{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,

  dbus,
  libcap,
  nss,
  libpcap,
  glib,
  gtk3,
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
  ];

  dontBuild = true;
  dontConfigure = true;
  noDumpEnvVars = true;

  # libpcap.so.0.8 is Debian-specific versioning; nixpkgs ships libpcap.so.1
  # warp-dex (diagnostic tool) links against it, but warp-cli and warp-svc work fine
  autoPatchelfIgnoreMissingDeps = [ "libpcap.so.0.8" ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    cp -r usr/bin/* $out/bin/ || true
    cp -r usr/lib/* $out/lib/ || true
    # Also install the main binaries from /bin if present
    cp -r bin/* $out/bin/ 2>/dev/null || true
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
