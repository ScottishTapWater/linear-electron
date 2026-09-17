#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
arch=${1:-$(native_arch)}
check_arch "$arch"
dist="$LINEAR_ROOT/dist"
bundle=$(jq -er .bundle "$dist/bundle-$arch.json")
version=$(jq -er .version "$dist/bundle-$arch.json")
check_version "$version"
case $(native_arch) in
  x64) host=x86_64; tool_hash=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0 ;;
  arm64) host=aarch64; tool_hash=f0837e7448a0c1e4e650a93bb3e85802546e60654ef287576f46c71c126a9158 ;;
esac
case $arch in
  x64) target=x86_64; runtime_hash=1cc49bcf1e2ccd593c379adb17c9f85a36d619088296504de95b1d06215aebbf ;;
  arm64) target=aarch64; runtime_hash=7d5d772b7c32f0c84caf0a452a3072a5709027d7eac5856feb89a7a7a8881372 ;;
esac
tool="$dist/appimagetool-1.9.1-$host"
runtime="$dist/runtime-$target"
download_verified "https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-$host.AppImage" "$tool" "$tool_hash"
# The continuous URL is mutable; the digest fails closed if upstream replaces it.
download_verified "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-$target" "$runtime" "$runtime_hash"
chmod 755 "$tool"
stage=$(mktemp -d "$dist/.appimage-XXXXXX")
app_dir="$stage/Linear.AppDir"
mkdir -p "$app_dir/usr/lib"
cp -a "$bundle" "$app_dir/usr/lib/linear-electron"
install -m644 "$LINEAR_ROOT/packaging/linear-electron.desktop" "$LINEAR_ROOT/packaging/linear-electron.svg" "$app_dir/"
install -m755 "$LINEAR_ROOT/packaging/AppRun" "$app_dir/AppRun"
ARCH=$target SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-0} "$tool" --appimage-extract-and-run \
  --runtime-file "$runtime" "$app_dir" "$dist/linear-electron-$target-v$version.AppImage"
