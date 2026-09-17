#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# -ge 1 && $# -le 3 ]] || die 'Usage: generate-pkgbuilds.sh VERSION [ARTIFACT_DIR] [--local-source]'
version=$1
check_version "$version"
dist=$(realpath "${2:-$LINEAR_ROOT/dist}")
local_source=false
if [[ $# == 3 ]]; then
  [[ $3 == --local-source ]] || die "Unknown option: $3"
  local_source=true
fi
base="https://github.com/hughesjs/linear-electron/releases/download/v$version"
variants=(linear-electron linear-electron-git linear-electron-bin linear-electron-appimage)
source_file="linear-electron-$version.tar.gz"
assets=("$source_file" "linear-electron-x64-v$version.tar.gz" "linear-electron-arm64-v$version.tar.gz"
  "linear-electron-x86_64-v$version.AppImage" "linear-electron-aarch64-v$version.AppImage")
declare -A hashes
for file in "${assets[@]}"; do hashes[$file]=$(sha256 "$dist/$file"); done
for file in "${assets[@]}"; do printf '%s  %s\n' "${hashes[$file]}" "$file"; done | sort -k2 > "$dist/SHA256SUMS"

emit_source() {
  local suffix=$1 file=$2 url
  if $local_source; then
    url=$file
    ln -sfn -- "$dist/$file" "$output/$file"
  else
    url="$base/$file"
  fi
  printf 'source%s=(%q)\nsha256sums%s=(%q)\n' "$suffix" "$url" "$suffix" "${hashes[$file]}"
}

emit_recipe() {
  local name=$1 other binary=false image=false vcs=false
  [[ $name == linear-electron-git ]] && vcs=true
  [[ $name == linear-electron-appimage ]] && image=true
  if $image || [[ $name == linear-electron-bin ]]; then binary=true; fi
  printf '# Maintainer: James H <james@jamesmcmahon.co.uk>\npkgname=%s\npkgver=%s\npkgrel=1\n' "$name" "$version"
  printf "pkgdesc='Unofficial Linear desktop app (%s)'\n" "$name"
  printf "arch=('x86_64' 'aarch64')\nurl='https://github.com/hughesjs/linear-electron'\n"
  if $binary; then printf "license=('MIT' 'LicenseRef-Linear-Brand' 'LicenseRef-Electron-Chromium')\n"; else printf "license=('MIT' 'LicenseRef-Linear-Brand')\n"; fi
  # Literal variables below are expanded later by makepkg, not this generator.
  # shellcheck disable=SC2016
  [[ $name == linear-electron ]] || printf 'provides=("linear-electron=$pkgver")\n'
  printf 'conflicts=('
  for other in "${variants[@]}"; do [[ $other == "$name" ]] || printf '%q ' "$other"; done
  printf ")\noptions=('!strip' '!debug')\n"
  if ! $binary; then
    printf "depends=('electron44' 'xdg-utils')\nmakedepends=('jq'"
    $vcs && printf " 'git'"
    printf ')\n'
    if $vcs; then
      printf 'source=(%q)\n' "linear-electron::${LINEAR_GIT_SOURCE:-git+https://github.com/hughesjs/linear-electron.git#branch=main}"
      cat <<'PKG'
sha256sums=('SKIP')

pkgver() {
  cd linear-electron
  local tag
  tag=$(git describe --tags --match 'v[0-9]*' --abbrev=0 2>/dev/null || true)
  if [[ -n "$tag" ]]; then
    printf '%s.r%s.g%s' "${tag#v}" "$(git rev-list --count "$tag"..HEAD)" "$(git rev-parse --short HEAD)"
  else
    printf '0.0.0.r%s.g%s' "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
  fi
}

package() {
  cd linear-electron
PKG
    else
      emit_source '' "$source_file"
      # shellcheck disable=SC2016
      printf '\npackage() {\n  cd "linear-electron-$pkgver"\n'
    fi
    cat <<'PKG'
  bash scripts/stage-app.sh "$pkgdir/usr/lib/linear-electron" "$pkgver"
  install -Dm755 packaging/linear-electron-system "$pkgdir/usr/bin/linear-electron"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
PKG
  else
    printf "depends=('gtk3' 'nss' 'alsa-lib' 'libxss' 'libxtst' 'libxrandr' 'libxkbcommon' 'libdrm' 'mesa' 'libnotify' 'xdg-utils'"
    $image && printf " 'fuse3'"
    printf ')\n'
    if $image; then
      emit_source _x86_64 "linear-electron-x86_64-v$version.AppImage"
      emit_source _aarch64 "linear-electron-aarch64-v$version.AppImage"
      emit_source '' "$source_file"
      printf "noextract=('linear-electron-x86_64-v%s.AppImage' 'linear-electron-aarch64-v%s.AppImage')\n" "$version" "$version"
      cat <<'PKG'

package() {
  install -Dm755 "linear-electron-$CARCH-v$pkgver.AppImage" "$pkgdir/opt/linear-electron/linear-electron.AppImage"
  cd "linear-electron-$pkgver"
  install -Dm755 packaging/linear-electron-appimage "$pkgdir/usr/bin/linear-electron"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
PKG
    else
      emit_source _x86_64 "linear-electron-x64-v$version.tar.gz"
      emit_source _aarch64 "linear-electron-arm64-v$version.tar.gz"
      cat <<'PKG'

package() {
  local bundle_arch=x64
  [[ "$CARCH" = aarch64 ]] && bundle_arch=arm64
  cd "linear-electron-$bundle_arch-v$pkgver"
  install -dm755 "$pkgdir/opt/linear-electron"
  cp -a --no-preserve=ownership . "$pkgdir/opt/linear-electron/"
  chmod 4755 "$pkgdir/opt/linear-electron/chrome-sandbox"
  install -Dm755 packaging/linear-electron "$pkgdir/usr/bin/linear-electron"
  for notice in LICENSE LICENSE.electron LICENSES.chromium.html; do
    install -Dm644 "$notice" "$pkgdir/usr/share/licenses/$pkgname/$notice"
  done
PKG
    fi
  fi
  cat <<'PKG'
  install -Dm644 packaging/linear-electron.desktop "$pkgdir/usr/share/applications/linear-electron.desktop"
  install -Dm644 packaging/linear-electron.png "$pkgdir/usr/share/icons/hicolor/1024x1024/apps/linear-electron.png"
  install -Dm644 packaging/LINEAR-BRAND-NOTICE "$pkgdir/usr/share/licenses/$pkgname/LINEAR-BRAND-NOTICE"
}
PKG
}

for variant in "${variants[@]}"; do
  output="$dist/aur/$variant"
  mkdir -p "$output"
  emit_recipe "$variant" > "$output/PKGBUILD"
done
