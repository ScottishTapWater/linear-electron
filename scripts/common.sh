#!/usr/bin/env bash
# Shared packaging helpers. This file is sourced, not executed.
export LINEAR_ROOT
LINEAR_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

die() { printf '%s\n' "$*" >&2; exit 1; }
check_version() { [[ ${1:-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'Expected numeric X.Y.Z version'; }
check_arch() { [[ ${1:-} == x64 || ${1:-} == arm64 ]] || die 'Supported architectures: x64, arm64'; }
native_arch() {
  case $(uname -m) in x86_64) echo x64 ;; aarch64) echo arm64 ;; *) die 'Unsupported host architecture' ;; esac
}
sha256() { sha256sum "$1" | cut -d ' ' -f 1; }
download_verified() {
  local url=$1 target=$2 expected=$3 temporary
  [[ $expected =~ ^[a-f0-9]{64}$ ]] || die "Missing pinned checksum: $target"
  if [[ ! -f $target ]]; then
    temporary=$(mktemp "${target}.download.XXXXXX")
    if ! curl --fail --location --retry 3 --output "$temporary" "$url"; then
      rm -- "$temporary"
      die "Download failed: $url"
    fi
    if [[ $(sha256 "$temporary") != "$expected" ]]; then
      rm -- "$temporary"
      die "Checksum mismatch: $url"
    fi
    mv -- "$temporary" "$target"
  fi
  [[ $(sha256 "$target") == "$expected" ]] || die "Checksum mismatch: $target; refusing to execute/extract"
}
