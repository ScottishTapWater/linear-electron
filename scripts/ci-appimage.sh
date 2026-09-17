#!/usr/bin/env bash
set -euo pipefail
[[ ${GITHUB_ACTIONS:-} == true ]] || { echo 'GitHub runner only' >&2; exit 1; }
image=$1
chmod +x "$image"
# Ubuntu's AppArmor restricts user namespaces. Grant only this CI app permission;
# do not disable AppArmor or pass --no-sandbox to Chromium.
if command -v apparmor_parser >/dev/null && sudo aa-status --enabled; then
  sudo install -m644 packaging/linear-electron-ci.apparmor /etc/apparmor.d/linear-electron-ci
  sudo apparmor_parser -r /etc/apparmor.d/linear-electron-ci
fi
dbus-run-session xvfb-run -a "$image" --self-test
APPIMAGE_EXTRACT_AND_RUN=1 dbus-run-session xvfb-run -a "$image" --self-test
