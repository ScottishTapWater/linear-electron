#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
version=${1:-$(jq -r .version "$LINEAR_ROOT/package.json")}
check_version "$version"
cat <<EOF
Name:           linear-electron
Version:        $version
Release:        1%{?dist}
Summary:        Unofficial Electron wrapper for Linear
License:        MIT AND BSD-3-Clause AND LicenseRef-Linear-Brand
URL:            https://github.com/hughesjs/linear-electron

%ifarch x86_64
%global bundle_arch x64
Source0:        https://github.com/hughesjs/linear-electron/releases/download/v%{version}/linear-electron-x64-v%{version}.tar.gz
%endif
%ifarch aarch64
%global bundle_arch arm64
Source0:        https://github.com/hughesjs/linear-electron/releases/download/v%{version}/linear-electron-arm64-v%{version}.tar.gz
%endif

ExclusiveArch:  x86_64 aarch64
AutoReqProv:    no
%global debug_package %{nil}
%global __os_install_post %{nil}
%define __strip /bin/true
Requires:       alsa-lib
Requires:       at-spi2-core
Requires:       cups-libs
Requires:       dbus-libs
Requires:       gtk3
Requires:       libdrm
Requires:       libX11
Requires:       libXcomposite
Requires:       libXdamage
Requires:       libXext
Requires:       libXfixes
Requires:       libXrandr
Requires:       libxkbcommon
Requires:       mesa-libgbm
Requires:       nss
Requires:       pango

%description
An unofficial Linux wrapper for Linear using a bundled Electron and Chromium
runtime instead of the system WebKitGTK. It was created after encountering
WebKitGTK freezes during sign-in with the Tauri-based linear-desktop client.

This project is not affiliated with or endorsed by Linear.

%prep
%setup -q -n linear-electron-%{bundle_arch}-v%{version}

%build
# The release archive contains the tested upstream Electron runtime.

%install
install -dm755 %{buildroot}/opt/linear-electron
cp -a --no-preserve=ownership . %{buildroot}/opt/linear-electron/
chmod 4755 %{buildroot}/opt/linear-electron/chrome-sandbox
install -Dm755 packaging/linear-electron %{buildroot}%{_bindir}/linear-electron
install -Dm644 packaging/linear-electron.desktop %{buildroot}%{_datadir}/applications/linear-electron.desktop
install -Dm644 packaging/linear-electron.png %{buildroot}%{_datadir}/icons/hicolor/1024x1024/apps/linear-electron.png

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/linear-electron.desktop

%files
%license LICENSE LICENSE.electron LICENSES.chromium.html packaging/LINEAR-BRAND-NOTICE
%doc README.md
%{_bindir}/linear-electron
/opt/linear-electron/
%{_datadir}/applications/linear-electron.desktop
%{_datadir}/icons/hicolor/1024x1024/apps/linear-electron.png

%changelog
* $(LC_ALL=C date '+%a %b %d %Y') James H <james@jamesmcmahon.co.uk> - $version-1
- Release $version
EOF
