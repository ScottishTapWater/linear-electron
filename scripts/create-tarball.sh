#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
version=${1:-$(jq -r .version "$LINEAR_ROOT/package.json")}
arch=${2:-$(native_arch)}
check_version "$version"
check_arch "$arch"
electron_version=$(jq -r .devDependencies.electron "$LINEAR_ROOT/package.json")
dist="$LINEAR_ROOT/dist"
mkdir -p "$dist"
zip="electron-v$electron_version-linux-$arch.zip"
checksum=$(jq -er --arg zip "$zip" '.[$zip]' "$LINEAR_ROOT/node_modules/electron/checksums.json")
download_verified "https://github.com/electron/electron/releases/download/v$electron_version/$zip" "$dist/$zip" "$checksum"
name="linear-electron-$arch-v$version"
stage=$(mktemp -d "$dist/.bundle-XXXXXX")
bundle="$stage/$name"
mkdir "$bundle"
bsdtar -xf "$dist/$zip" -C "$bundle"
machine=$(od -An -tu2 -j18 -N2 "$bundle/electron" | tr -d ' ')
case "$arch:$machine" in x64:62|arm64:183) ;; *) die 'Wrong runtime architecture' ;; esac
mv "$bundle/electron" "$bundle/linear-electron"
mv "$bundle/LICENSE" "$bundle/LICENSE.electron"
# This is the known demo file in the newly extracted Electron archive only.
rm -- "$bundle/resources/default_app.asar"
bash "$LINEAR_ROOT/scripts/stage-app.sh" "$bundle/resources/app" "$version"
install -m644 "$LINEAR_ROOT/LICENSE" "$LINEAR_ROOT/README.md" "$bundle/"
cp -a "$LINEAR_ROOT/packaging" "$bundle/packaging"
chmod 755 "$bundle/chrome-sandbox"
tar -czf "$dist/$name.tar.gz" -C "$stage" "$name"
jq -n --arg bundle "$bundle" --arg version "$version" --arg arch "$arch" '{bundle:$bundle,version:$version,arch:$arch}' > "$dist/bundle-$arch.json"
printf '%s\n' "$dist/$name.tar.gz"
