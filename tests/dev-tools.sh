#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf "ERROR %s\n" "$*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"

  grep -Fq "$expected" "$file" || fail "Expected ${file#"$ROOT_DIR"/} to contain: $expected"
}

for distro in ubuntu fedora; do
  base_script="$ROOT_DIR/install-$distro/terminal/00-base.sh"
  desktop_script="$ROOT_DIR/install-$distro/desktop/10-apps.sh"
  lib_script="$ROOT_DIR/install-$distro/lib.sh"

  assert_contains "$base_script" "fzf"
  assert_contains "$base_script" "ripgrep"
  assert_contains "$base_script" "nodejs"
  assert_contains "$base_script" "npm"
  assert_contains "$base_script" "install_lazygit"
  assert_contains "$base_script" "install_atuin"
  assert_contains "$base_script" "install_yazi"
  assert_contains "$base_script" "install_npm_global_package opencode opencode-ai"
  assert_contains "$base_script" "install_npm_global_package codex @openai/codex"
  # shellcheck disable=SC2016
  assert_contains "$base_script" 'eval "$(atuin init bash)"'

  assert_contains "$desktop_script" "install_opencode_desktop"

  assert_contains "$lib_script" "github_latest_asset_url"
  assert_contains "$lib_script" "install_npm_global_package()"
  assert_contains "$lib_script" "install_lazygit()"
  assert_contains "$lib_script" "install_atuin()"
  assert_contains "$lib_script" "install_yazi()"
  assert_contains "$lib_script" "install_opencode_desktop()"
done

assert_contains "$ROOT_DIR/install-ubuntu/lib.sh" "https://opencode.ai/download/stable/linux-x64-deb"
assert_contains "$ROOT_DIR/install-fedora/lib.sh" "https://opencode.ai/download/stable/linux-x64-rpm"

printf "Developer tool checks passed\n"
