#!/usr/bin/env bash

RUNNING_GNOME="false"
GNOME_SETTINGS_CHANGED="false"
REQUIRES_REBOOT="false"
TARGET_USER="${USER}"
TARGET_HOME="${HOME}"
export TARGET_USER TARGET_HOME
OMAKUB_THEME_REPO="https://raw.githubusercontent.com/basecamp/omakub/master"
SUPPORTED_THEMES=(
  "tokyo-night"
  "catppuccin"
  "nord"
  "everforest"
  "gruvbox"
  "kanagawa"
  "ristretto"
  "rose-pine"
  "matte-black"
  "osaka-jade"
)

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

error() {
  echo "[ERROR] $*" >&2
}

require_sudo() {
  sudo -v
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

apt_install() {
  sudo apt-get install -y "$@"
}

normalize_theme_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

theme_supported() {
  local candidate
  candidate="$(normalize_theme_name "$1")"

  local theme
  for theme in "${SUPPORTED_THEMES[@]}"; do
    if [[ "$theme" == "$candidate" ]]; then
      return 0
    fi
  done

  return 1
}

list_supported_themes() {
  printf '%s\n' "${SUPPORTED_THEMES[@]}"
}

add_line_if_missing() {
  local line="$1"
  local file="$2"

  touch "$file"

  if ! grep -Fqx "$line" "$file"; then
    echo "$line" >> "$file"
  fi
}

flatpak_install_app() {
  local app_id="$1"

  if flatpak info "$app_id" >/dev/null 2>&1; then
    log "Updating Flatpak: $app_id"
    flatpak update -y "$app_id"
  else
    log "Installing Flatpak: $app_id"
    flatpak install -y flathub "$app_id"
  fi
}

download_file() {
  local url="$1"
  local destination="$2"

  mkdir -p "$(dirname "$destination")"
  curl -fsSL "$url" -o "$destination"
}

install_dust() {
  if command_exists dust; then
    log "dust is already installed."
    return
  fi

  log "Installing dust using the official installer..."
  curl -sSfL https://raw.githubusercontent.com/bootandy/dust/refs/heads/master/install.sh | sh
}

detect_desktop() {
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]]; then
    RUNNING_GNOME="true"
  fi
}

configure_gnome_for_install() {
  log "Disabling GNOME auto-lock and suspend while installation runs..."
  gsettings set org.gnome.desktop.screensaver lock-enabled false
  gsettings set org.gnome.desktop.session idle-delay 0
  GNOME_SETTINGS_CHANGED="true"
}

cleanup() {
  if [[ "$RUNNING_GNOME" == "true" && "$GNOME_SETTINGS_CHANGED" == "true" ]]; then
    log "Restoring GNOME lock and idle settings..."
    gsettings set org.gnome.desktop.screensaver lock-enabled true || true
    gsettings set org.gnome.desktop.session idle-delay 300 || true
  fi
}

mark_reboot_required() {
  REQUIRES_REBOOT="true"
}

apply_selected_theme() {
  local theme="${1:-}"

  if [[ -z "$theme" ]]; then
    return
  fi

  if [[ "$RUNNING_GNOME" != "true" ]]; then
    warn "Skipping theme '$theme' because GNOME was not detected."
    return
  fi

  if ! theme_supported "$theme"; then
    error "Unsupported theme: $theme"
    warn "Supported themes:"
    list_supported_themes >&2
    exit 1
  fi

  local omakub_root="$TARGET_HOME/.local/share/omakub"
  local theme_dir="$omakub_root/themes/$theme"

  log "Applying theme: $theme"
  download_file "$OMAKUB_THEME_REPO/themes/$theme/background.jpg" "$theme_dir/background.jpg"
  download_file "$OMAKUB_THEME_REPO/themes/$theme/gnome.sh" "$theme_dir/gnome.sh"
  download_file "$OMAKUB_THEME_REPO/themes/set-gnome-theme.sh" "$omakub_root/themes/set-gnome-theme.sh"

  export OMAKUB_PATH="$omakub_root"

  # shellcheck source=/dev/null
  source "$theme_dir/gnome.sh"
}

finish_installation() {
  log "Installation complete."
  warn "Open a new terminal to load the updated PATH and aliases."

  if [[ "$REQUIRES_REBOOT" == "true" ]]; then
    warn "Reboot the computer before using Samba/Nautilus Share. Logoff/login is not enough."
  fi
}
