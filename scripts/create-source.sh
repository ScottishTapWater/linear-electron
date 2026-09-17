#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
version=${1:-$(jq -r .version "$LINEAR_ROOT/package.json")}
check_version "$version"
dist="$LINEAR_ROOT/dist"
mkdir -p "$dist"
stage=$(mktemp -d "$dist/.source-XXXXXX")
name="linear-electron-$version"
mkdir "$stage/$name"
# Explicit allowlist: never copy the entire checkout, profiles or screenshots.
for item in src scripts packaging test LICENSE README.md package.json pnpm-lock.yaml pnpm-workspace.yaml; do
  cp -a "$LINEAR_ROOT/$item" "$stage/$name/"
done
jq --arg version "$version" '.version=$version' "$LINEAR_ROOT/package.json" > "$stage/$name/package.json"
tar -czf "$dist/$name.tar.gz" -C "$stage" "$name"
printf '%s\n' "$dist/$name.tar.gz"
