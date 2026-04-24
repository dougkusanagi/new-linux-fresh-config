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

  grep -Fq "$expected" "$file" || fail "Expected ${file#$ROOT_DIR/} to contain: $expected"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq "$unexpected" "$file"; then
    fail "Did not expect ${file#$ROOT_DIR/} to contain: $unexpected"
  fi
}

for distro in ubuntu fedora; do
  base_script="$ROOT_DIR/install-$distro/terminal/00-base.sh"
  web_stack_script="$ROOT_DIR/install-$distro/terminal/10-web-stack.sh"
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
  assert_contains "$base_script" 'eval "$(atuin init bash)"'
  assert_contains "$base_script" "configure_static_ipv4_network"

  assert_contains "$desktop_script" "install_opencode_desktop"
  assert_contains "$desktop_script" 'flatpak_install_app "com.github.dynobo.normcap"'
  assert_contains "$desktop_script" 'flatpak_install_app "com.visualstudio.code"'
  assert_contains "$desktop_script" 'flatpak_install_app "com.google.Chrome"'
  assert_contains "$desktop_script" 'flatpak_install_app "io.podman_desktop.PodmanDesktop"'
  assert_contains "$desktop_script" 'flatpak_install_app "it.mijorus.gearlever"'
  assert_contains "$desktop_script" "install_lm_studio"
  assert_not_contains "$desktop_script" 'flatpak_install_app "ai.lmstudio.LMStudio"'
  assert_contains "$desktop_script" 'flatpak_install_app "io.github.zen_browser.zen"'
  assert_contains "$desktop_script" 'flatpak_install_app "io.missioncenter.MissionCenter"'
  assert_contains "$desktop_script" 'flatpak_install_app "com.discordapp.Discord"'
  assert_contains "$desktop_script" 'flatpak_install_app "com.ktechpit.whatsie"'
  assert_contains "$desktop_script" 'flatpak_install_app "com.valvesoftware.Steam"'
  assert_contains "$desktop_script" 'flatpak_install_app "net.lutris.Lutris"'
  assert_contains "$desktop_script" 'flatpak_install_app "com.vysp3r.ProtonPlus"'
  assert_contains "$desktop_script" 'flatpak_install_app "com.heroicgameslauncher.hgl"'
  assert_contains "$desktop_script" 'flatpak_install_app "com.usebottles.bottles"'

  assert_contains "$web_stack_script" "php-opcache"

  assert_contains "$lib_script" "github_latest_asset_url"
  assert_contains "$lib_script" "install_npm_global_package()"
  assert_contains "$lib_script" "install_lazygit()"
  assert_contains "$lib_script" "install_atuin()"
  assert_contains "$lib_script" "install_yazi()"
  assert_contains "$lib_script" "install_lm_studio()"
  assert_contains "$lib_script" "https://lmstudio.ai/download/latest/linux/x64?format=AppImage"
  assert_contains "$lib_script" "install_opencode_desktop()"
  assert_contains "$lib_script" "configure_static_ipv4_network()"
  assert_contains "$lib_script" 'STATIC_NETWORK_ADDRESS="${STATIC_NETWORK_ADDRESS:-192.168.1.77/24}"'
  assert_contains "$lib_script" 'STATIC_NETWORK_GATEWAY="${STATIC_NETWORK_GATEWAY:-192.168.1.1}"'
  assert_contains "$lib_script" 'STATIC_NETWORK_DNS="${STATIC_NETWORK_DNS:-1.1.1.1}"'
done

assert_contains "$ROOT_DIR/install-ubuntu/lib.sh" "apt_install_optional()"
assert_contains "$ROOT_DIR/install-ubuntu/lib.sh" "apt_keyring_exists()"
assert_contains "$ROOT_DIR/install-ubuntu/lib.sh" "install_apt_keyring_file()"
assert_contains "$ROOT_DIR/install-ubuntu/lib.sh" "install_apt_dearmored_keyring()"
assert_contains "$ROOT_DIR/install-ubuntu/terminal/00-base.sh" "install_apt_keyring_file"
assert_contains "$ROOT_DIR/install-ubuntu/terminal/00-base.sh" "install_apt_dearmored_keyring"
assert_not_contains "$ROOT_DIR/install-ubuntu/terminal/00-base.sh" "sudo gpg --dearmor -o /etc/apt/keyrings"
assert_contains "$ROOT_DIR/install-ubuntu/desktop/10-apps.sh" "apt_install_optional steam-devices joystick jstest-gtk gamemode mangohud gamescope goverlay"
assert_contains "$ROOT_DIR/install-fedora/desktop/10-apps.sh" "dnf_install_optional steam-devices joystick-support gamemode mangohud gamescope goverlay xone xpadneo"
assert_contains "$ROOT_DIR/install-ubuntu/desktop/20-gnome-settings.sh" "set_gsettings_key_if_exists org.gnome.settings-daemon.plugins.media-keys screenshot"
assert_contains "$ROOT_DIR/install-ubuntu/desktop/20-gnome-settings.sh" "Flameshot configured as the primary Print Screen tool"
assert_contains "$ROOT_DIR/install-fedora/desktop/20-gnome-settings.sh" "set_gsettings_key_if_exists org.gnome.settings-daemon.plugins.media-keys screenshot"
assert_contains "$ROOT_DIR/install-fedora/desktop/20-gnome-settings.sh" "Flameshot configured as the primary Print Screen tool"
assert_contains "$ROOT_DIR/install-ubuntu/lib.sh" "apt_install_first_available()"
assert_contains "$ROOT_DIR/install-ubuntu/terminal/10-web-stack.sh" "PHP_OPCACHE_PACKAGES=(php-opcache)"
assert_contains "$ROOT_DIR/install-ubuntu/terminal/10-web-stack.sh" "Zend OPcache"
assert_contains "$ROOT_DIR/install-ubuntu/terminal/10-web-stack.sh" "apt-cache search --names-only"
assert_contains "$ROOT_DIR/install-ubuntu/terminal/10-web-stack.sh" 'apt_install_first_available "${PHP_OPCACHE_PACKAGES[@]}"'
assert_contains "$ROOT_DIR/install-ubuntu/lib.sh" "https://opencode.ai/download/stable/linux-x64-deb"
assert_contains "$ROOT_DIR/install-fedora/lib.sh" "https://opencode.ai/download/stable/linux-x64-rpm"

printf "Developer tool checks passed\n"
