#!/usr/bin/env bash
# Runs only inside a disposable CI container, never on the workstation.
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ ${LINEAR_CI_CONTAINER:-} == 1 && -f /.dockerenv ]] || { echo 'CI container required' >&2; exit 1; }
version=$1
check_version "$version"
case ${FEDORA_VERSION:-} in 43|44|rawhide) ;; *) die 'Expected Fedora 43, 44 or rawhide' ;; esac
case $(uname -m) in x86_64) bundle_arch=x64 ;; aarch64) bundle_arch=arm64 ;; *) exit 2 ;; esac
dnf -y install rpm-build desktop-file-utils dbus-x11 xorg-x11-server-Xvfb \
  alsa-lib at-spi2-core cups-libs dbus-libs gtk3 libdrm libX11 libXcomposite \
  libXdamage libXext libXfixes libXrandr libxkbcommon mesa-libgbm nss pango shadow-utils
topdir=$(mktemp -d "/work/dist/.rpmbuild-$(uname -m)-$FEDORA_VERSION-XXXXXX")
mkdir -p "$topdir"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cp "/work/dist/linear-electron-$bundle_arch-v$version.tar.gz" "$topdir/SOURCES/"
bash /work/scripts/generate-specfile.sh "$version" > "$topdir/SPECS/linear-electron.spec"
rpmbuild -ba --define "_topdir $topdir" "$topdir/SPECS/linear-electron.spec"
rpm_file=$(find "$topdir/RPMS/$(uname -m)" -name 'linear-electron-*.rpm' -type f -print -quit)
test -n "$rpm_file"
dnf -y install "$rpm_file"
rpm -V linear-electron
desktop-file-validate /usr/share/applications/linear-electron.desktop
test "$(stat -c '%U:%G %a' /opt/linear-electron/chrome-sandbox)" = 'root:root 4755'
useradd -m builder
# The single-quoted script is intentionally expanded by the inner shell.
# shellcheck disable=SC2016
runuser -u builder -- bash -c '
  set -euo pipefail
  Xvfb :99 -screen 0 1280x800x24 >/tmp/linear-xvfb.log 2>&1 &
  xvfb_pid=$!
  trap "kill $xvfb_pid 2>/dev/null || true" EXIT
  DISPLAY=:99 dbus-run-session -- /usr/bin/linear-electron --self-test
'
profile=/home/builder/.config/linear-electron
runuser -u builder -- mkdir -p "$profile"
runuser -u builder -- touch "$profile/ci-preserve-marker"
dnf -y remove linear-electron
test -f "$profile/ci-preserve-marker"
test ! -e /usr/bin/linear-electron
mkdir -p /work/dist/rpm-results
cp "$rpm_file" "$topdir/SRPMS"/*.src.rpm /work/dist/rpm-results/
