#!/usr/bin/env bash
# Runs only inside the disposable CI container, never on the workstation.
set -euo pipefail
[[ ${LINEAR_CI_CONTAINER:-} == 1 && -f /.dockerenv ]] || { echo 'CI container required' >&2; exit 1; }
variant=$1
version=$2
case "$variant" in linear-electron|linear-electron-git|linear-electron-bin|linear-electron-appimage) ;; *) exit 2 ;; esac
# Landlock is not available in every GitHub container; this affects pacman only.
printf '\nDisableSandbox\n' >> /etc/pacman.conf
# Official Arch images omit docs/locales by default. Test the complete package,
# including files which pacman -Qkk otherwise correctly reports as missing.
sed -i '/^[[:space:]]*NoExtract[[:space:]]*=/d' /etc/pacman.conf
pacman-key --init
if [[ $(uname -m) == aarch64 ]]; then pacman-key --populate archlinuxarm; fi
pacman -Syu --noconfirm
pacman -S --needed --noconfirm base-devel git jq sudo desktop-file-utils xorg-server-xvfb xorg-xauth dbus fuse3
useradd -m builder
printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/linear-ci
chown -R builder:builder /work
if [[ "$variant" == linear-electron || "$variant" == linear-electron-git ]]; then
  if [[ $(uname -m) == aarch64 ]]; then
    sudo -u builder git clone https://aur.archlinux.org/electron44-bin.git /tmp/electron44-bin
    sudo -u builder git -C /tmp/electron44-bin checkout ae3c7634c51a1024080ecaaf73a12793a6596bda
    (cd /tmp/electron44-bin && sudo -u builder makepkg -si --noconfirm)
  else
    pacman -S --needed --noconfirm electron44
  fi
fi
fixture=$(sudo -u builder bash scripts/create-git-fixture.sh "$version")
sudo -u builder env LINEAR_GIT_SOURCE="$fixture" bash scripts/generate-pkgbuilds.sh "$version" dist --local-source
cd "dist/aur/$variant"
sudo -u builder makepkg -si --noconfirm
sudo -u builder bash -c 'makepkg --printsrcinfo > .SRCINFO'
desktop-file-validate /usr/share/applications/linear-electron.desktop
pacman -Qkk "$variant"
test -x /usr/bin/linear-electron
mkdir -p /work/dist/test-results
chown builder:builder /work/dist/test-results
sudo -u builder dbus-run-session xvfb-run -a /usr/bin/linear-electron --self-test | tee "/work/dist/test-results/$variant-$(uname -m).log"
grep -q '"result":"PASS"' "/work/dist/test-results/$variant-$(uname -m).log"
profile=$(sudo -u builder /usr/bin/linear-electron --profile-path)
[[ "$profile" == /home/builder/.config/linear-electron ]]
sudo -u builder mkdir -p "$profile"
sudo -u builder touch "$profile/ci-preserve-marker"
if [[ "$variant" == linear-electron-appimage ]]; then
  sudo -u builder env APPIMAGE_EXTRACT_AND_RUN=1 dbus-run-session xvfb-run -a /usr/bin/linear-electron --self-test
fi
# Removing one variant must not delete the shared profile.
pacman -R --noconfirm "$variant"
test -f "$profile/ci-preserve-marker"
test ! -e /usr/bin/linear-electron
# Publishable recipes use release URLs, never this job's local fixture paths.
cd /work
sudo -u builder bash scripts/generate-pkgbuilds.sh "$version" dist
cd "dist/aur/$variant"
sudo -u builder bash -c 'makepkg --printsrcinfo > .SRCINFO'
