{
  lib,
  nix-prefetch-scripts,
  writeShellApplication,
  jq,
  coreutils,
  curl,
}:
let
  constants = lib.importJSON ./constants.json;
in
writeShellApplication {
  name = "cloudflare-warp-bin-update";
  runtimeInputs = [
    jq
    nix-prefetch-scripts
    coreutils
    curl
  ];
  text = ''
    set -euo pipefail

    echo "Fetching latest package info from ${constants.apt_repo}"

    AMD64_META=$(curl -sL "${constants.apt_repo}/dists/${constants.dist}/main/binary-amd64/Packages")
    ARM64_META=$(curl -sL "${constants.apt_repo}/dists/${constants.dist}/main/binary-arm64/Packages")

    VERSION=$(echo "$AMD64_META" | grep -m1 "^Version:" | awk '{print $2}')
    echo "Latest version: $VERSION"

    CURRENT_VERSION=$(jq -r '.version' version.json)
    echo "Flake version: $CURRENT_VERSION"
    if [ "$VERSION" = "$CURRENT_VERSION" ]; then
      echo "Version matches current version.json, skipping update"
      exit 0
    fi

    AMD64_FILENAME=$(echo "$AMD64_META" | grep -m1 "^Filename:" | awk '{print $2}')
    ARM64_FILENAME=$(echo "$ARM64_META" | grep -m1 "^Filename:" | awk '{print $2}')

    echo "Fetching x86_64-linux deb and calculating hash"
    X64_SHA256=$(nix-prefetch-url "${constants.apt_repo}/$AMD64_FILENAME")
    X64_HASH=$(nix-hash --to-sri --type sha256 "$X64_SHA256")
    echo "x86_64-linux hash: $X64_HASH"

    echo "Fetching aarch64-linux deb and calculating hash"
    ARM64_SHA256=$(nix-prefetch-url "${constants.apt_repo}/$ARM64_FILENAME")
    ARM64_HASH=$(nix-hash --to-sri --type sha256 "$ARM64_SHA256")
    echo "aarch64-linux hash: $ARM64_HASH"

    jq --arg version "$VERSION" \
       --arg hash_linux_x64 "$X64_HASH" \
       --arg hash_linux_arm64 "$ARM64_HASH" \
       '.version = $version |
        ."hash-linux-x64" = $hash_linux_x64 |
        ."hash-linux-arm64" = $hash_linux_arm64' \
       version.json > version.json.tmp
    mv version.json.tmp version.json
    echo "done updating version.json with new version and hashes"
  '';
}
