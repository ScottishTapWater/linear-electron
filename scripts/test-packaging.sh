#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
for script in "$LINEAR_ROOT"/scripts/*.sh; do bash -n "$script"; done
if (check_version '1.2.3;id') 2>/dev/null; then die 'Version injection accepted'; fi
if (check_arch aarch64) 2>/dev/null; then die 'Invalid architecture accepted'; fi
test_dir=$(mktemp -d)
# Retain fixtures on failure for diagnosis; all data is generated and non-sensitive.
for name in linear-electron-1.2.3.tar.gz linear-electron-x64-v1.2.3.tar.gz linear-electron-arm64-v1.2.3.tar.gz linear-electron-x86_64-v1.2.3.AppImage linear-electron-aarch64-v1.2.3.AppImage; do
  printf '%s\n' "$name" > "$test_dir/$name"
done
bash "$LINEAR_ROOT/scripts/generate-pkgbuilds.sh" 1.2.3 "$test_dir"
[[ $(wc -l < "$test_dir/SHA256SUMS") == 5 ]]
for name in linear-electron linear-electron-git linear-electron-bin linear-electron-appimage; do
  recipe="$test_dir/aur/$name/PKGBUILD"
  bash -n "$recipe"
  grep -q 'james@jamesmcmahon.co.uk' "$recipe"
  if grep -Eq -- '--no-sandbox|\.profile' "$recipe"; then die 'Unsafe recipe'; fi
  if [[ $name != linear-electron-git ]] && grep -q SKIP "$recipe"; then die 'Missing checksum'; fi
  for other in linear-electron linear-electron-git linear-electron-bin linear-electron-appimage; do
    [[ $other == "$name" ]] || grep '^conflicts=' "$recipe" | grep -qw "$other"
  done
done
bash "$LINEAR_ROOT/scripts/stage-app.sh" "$test_dir/app" 1.2.3
jq -e '.linearInstalled == true and .version == "1.2.3" and .dependencies == null' "$test_dir/app/package.json" >/dev/null
[[ $(find "$test_dir/app" -mindepth 1 -maxdepth 1 | wc -l) == 2 ]]
mkdir "$test_dir/path with spaces"
for file in "$test_dir"/*.tar.gz "$test_dir"/*.AppImage; do cp "$file" "$test_dir/path with spaces/"; done
bash "$LINEAR_ROOT/scripts/generate-pkgbuilds.sh" 1.2.3 "$test_dir/path with spaces" --local-source
(cd "$test_dir" && sha256sum -c SHA256SUMS >/dev/null)
printf 'PASS: Bash packaging syntax, validation, recipes, checksums and staged file allowlist\n'
