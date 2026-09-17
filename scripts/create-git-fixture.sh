#!/usr/bin/env bash
# Candidate source for local/CI VCS builds; never copies user profiles.
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
version=${1:-}
check_version "$version"
stage=$(mktemp -d "$LINEAR_ROOT/dist/.git-fixture-XXXXXX")
tar -xzf "$LINEAR_ROOT/dist/linear-electron-$version.tar.gz" -C "$stage"
repo="$stage/linear-electron-$version"
git -C "$repo" init -q -b main
git -C "$repo" config user.name 'Packaging fixture'
git -C "$repo" config user.email james@jamesmcmahon.co.uk
git -C "$repo" add .
git -C "$repo" commit -qm 'Candidate release source'
git -C "$repo" tag "v$version"
printf 'git+file://%s#branch=main\n' "$repo"
