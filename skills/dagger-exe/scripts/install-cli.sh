#!/usr/bin/env bash
# Install this skill's exact CLI into BIN_DIR (default ~/.local/bin).
set -euo pipefail
if [[ $# -ne 0 ]]; then
  echo "Usage: BIN_DIR=~/.local/bin $0" >&2
  exit 2
fi
version=1.0.0-beta.21
os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$(uname -m)" in
  x86_64|amd64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "Unsupported architecture; use an official release for your platform." >&2; exit 1 ;;
esac
case "$os/$arch" in
  darwin/amd64) expected=fdbe191c965d240ee9cc90719fa9dca1586805cbb89b0a0087314a84a0937354 ;;
  darwin/arm64) expected=781f4862c022a19b9a4c498b59e1d9cfda1ee3cdc8ce210e4545bd8842a7416d ;;
  linux/amd64) expected=c5ac777a5c99089869660943381136e22177b59a46412e310c2fef594760a041 ;;
  linux/arm64) expected=ba9d55638636918a3404313511bceba5cc0af22f487c1c1b6a5ba60ce70a61bb ;;
  *) echo "Only macOS and Linux are supported by this installer." >&2; exit 1 ;;
esac
target=${BIN_DIR:-"$HOME/.local/bin"}
mkdir -p "$target"
if [[ -x "$target/dagger" ]]; then
  existing=$("$target/dagger" version --quiet 2>/dev/null || true)
  if [[ "${existing%%+*}" == "v$version" ]]; then
    echo "Already installed: $existing ($target/dagger)"
    exit 0
  fi
  if [[ "${ALLOW_REPLACE_DAGGER:-0}" != 1 ]]; then
    echo "Refusing to replace $target/dagger ($existing)." >&2
    echo "Choose another BIN_DIR or deliberately set ALLOW_REPLACE_DAGGER=1." >&2
    exit 1
  fi
fi
temp=$(mktemp -d "${TMPDIR:-/tmp}/dagger-cli.XXXXXX")
cleanup() { rm -f -- "$temp/archive.tar.gz" "$temp/dagger"; rmdir "$temp" 2>/dev/null || true; }
trap cleanup EXIT
archive="dagger_v${version}_${os}_${arch}.tar.gz"
curl --fail --silent --show-error --location --retry 3 \
  "https://dl.dagger.io/dagger/releases/$version/$archive" -o "$temp/archive.tar.gz"
if command -v sha256sum >/dev/null; then
  actual=$(sha256sum "$temp/archive.tar.gz"); actual=${actual%% *}
elif command -v shasum >/dev/null; then
  actual=$(shasum -a 256 "$temp/archive.tar.gz"); actual=${actual%% *}
else
  echo "Need sha256sum or shasum." >&2; exit 1
fi
[[ "$actual" == "$expected" ]] || { echo "SHA-256 mismatch; refusing installation." >&2; exit 1; }
tar -xzf "$temp/archive.tar.gz" -C "$temp" dagger
install -m 755 "$temp/dagger" "$target/dagger"
echo "Installed $("$target/dagger" version --quiet) at $target/dagger"
echo "Ensure $target precedes other Dagger installations on PATH."
