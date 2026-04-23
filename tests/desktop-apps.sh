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

assert_flatpak_apps() {
  local distro="$1"
  local script="$ROOT_DIR/install-$distro/desktop/10-apps.sh"
  local expected=(
    "io.podman_desktop.PodmanDesktop"
    "org.qbittorrent.qBittorrent"
    "io.github.zen_browser.zen"
    "md.obsidian.Obsidian"
    "com.discordapp.Discord"
    "com.stremio.Stremio"
    "com.github.dynobo.normcap"
  )
  local actual=()
  local index

  mapfile -t actual < <(
    sed -n 's/^[[:space:]]*flatpak_install_app "\([^"]*\)".*/\1/p' "$script"
  )

  if [[ "${#actual[@]}" -ne "${#expected[@]}" ]]; then
    fail "Expected ${#expected[@]} Flatpak apps in ${script#"$ROOT_DIR"/}, found ${#actual[@]}"
  fi

  for index in "${!expected[@]}"; do
    if [[ "${actual[$index]}" != "${expected[$index]}" ]]; then
      fail "Expected ${script#"$ROOT_DIR"/} app $((index + 1)) to be ${expected[$index]}, found ${actual[$index]}"
    fi
  done

  assert_contains "$script" "install_opencode_desktop"
}

for distro in ubuntu fedora; do
  assert_flatpak_apps "$distro"
done

printf "Desktop app manifest checks passed\n"
