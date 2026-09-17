#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 2 ]] || die 'Usage: stage-app.sh DESTINATION VERSION'
destination=$1
version=$2
# makepkg's VCS version is also accepted here; jq handles JSON quoting.
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+([.][a-zA-Z0-9]+)*$ ]] || die 'Invalid app version'
install -dm755 "$destination/src"
for file in main.cjs policy.cjs smoke.cjs self-test.cjs test-preload.cjs; do
  install -m644 "$LINEAR_ROOT/src/$file" "$destination/src/$file"
done
install -Dm644 "$LINEAR_ROOT/packaging/linear-electron.png" "$destination/packaging/linear-electron.png"
install -Dm644 "$LINEAR_ROOT/packaging/LINEAR-BRAND-NOTICE" "$destination/packaging/LINEAR-BRAND-NOTICE"
jq -n --arg version "$version" '{name:"linear-electron",version:$version,main:"src/main.cjs",linearInstalled:true,license:"MIT"}' > "$destination/package.json"
chmod 644 "$destination/package.json"
