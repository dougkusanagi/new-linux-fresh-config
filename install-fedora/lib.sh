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

if [[ -t 1 ]]; then
  COLOR_RESET=$'\033[0m'
  COLOR_BOLD=$'\033[1m'
  COLOR_DIM=$'\033[2m'
  COLOR_BLUE=$'\033[34m'
  COLOR_GREEN=$'\033[32m'
  COLOR_YELLOW=$'\033[33m'
  COLOR_RED=$'\033[31m'
else
  COLOR_RESET=""
  COLOR_BOLD=""
  COLOR_DIM=""
  COLOR_BLUE=""
  COLOR_GREEN=""
  COLOR_YELLOW=""
  COLOR_RED=""
fi

section() {
  printf "\n%s%s%s\n" "${COLOR_BOLD}${COLOR_BLUE}" "$*" "${COLOR_RESET}"
}

log() {
  printf "%s->%s %s\n" "${COLOR_DIM}" "${COLOR_RESET}" "$*"
}

success() {
  printf "%sOK%s %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$*"
}

warn() {
  printf "%sWARN%s %s\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$*" >&2
}

error() {
  printf "%sERROR%s %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$*" >&2
}

join_by() {
  local delimiter="$1"
  shift

  local first="true"
  local item
  for item in "$@"; do
    if [[ "$first" == "true" ]]; then
      printf "%s" "$item"
      first="false"
    else
      printf "%s%s" "$delimiter" "$item"
    fi
  done
}

run_quiet() {
  local log_file exit_code
  log_file="$(mktemp)"

  if "$@" >"$log_file" 2>&1; then
    rm -f "$log_file"
    return 0
  else
    exit_code=$?
  fi

  error "Command failed: $*"
  sed -n '1,120p' "$log_file" >&2 || true
  rm -f "$log_file"
  return "$exit_code"
}

require_sudo() {
  if sudo -n true 2>/dev/null; then
    return
  fi

  if [[ ! -t 0 ]]; then
    error "sudo needs a password, but no interactive TTY is available."
    exit 1
  fi

  sudo -v
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

dnf_package_installed() {
  rpm -q "$1" >/dev/null 2>&1 || rpm -q --whatprovides "$1" >/dev/null 2>&1
}

dnf_update() {
  run_quiet sudo dnf makecache -y
  success "Package index updated"
}

dnf_install() {
  local allow_skip="${DNF_ALLOW_SKIP_UNAVAILABLE:-false}"
  local packages=("$@")
  local missing_packages=()
  local package

  for package in "${packages[@]}"; do
    if dnf_package_installed "$package"; then
      log "$package is already installed."
    else
      log "Installing $package..."
      missing_packages+=("$package")
    fi
  done

  if [[ "${#missing_packages[@]}" -eq 0 ]]; then
    return
  fi

  if [[ "$allow_skip" == "true" ]]; then
    run_quiet sudo dnf install -y --skip-unavailable "${missing_packages[@]}"
  else
    run_quiet sudo dnf install -y "${missing_packages[@]}"
  fi

  for package in "${missing_packages[@]}"; do
    if dnf_package_installed "$package"; then
      success "$package installed"
    elif [[ "$allow_skip" == "true" ]]; then
      warn "$package was not available and was skipped"
    else
      error "$package was not installed"
      return 1
    fi
  done
}

dnf_install_optional() {
  DNF_ALLOW_SKIP_UNAVAILABLE=true dnf_install "$@"
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
    run_quiet flatpak update -y "$app_id"
    success "Flatpak updated: $app_id"
  else
    run_quiet flatpak install -y --system flathub "$app_id"
    success "Flatpak installed: $app_id"
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
    log "dust is already available."
    return
  fi

  run_quiet bash -lc 'curl -sSfL https://raw.githubusercontent.com/bootandy/dust/refs/heads/master/install.sh | sh'
  success "dust installed"
}

install_sd() {
  if command_exists sd; then
    log "sd is already available."
    return
  fi

  local tmpdir url
  tmpdir="$(mktemp -d)"
  url="$(curl -sL https://api.github.com/repos/chmln/sd/releases/latest | jq -r '.assets[] | select(.name | test("x86_64.*linux-gnu\\.tar\\.gz$")) | .browser_download_url')"
  run_quiet bash -lc "curl -sSfL '$url' | tar xz -C '$tmpdir' && sudo mv '$tmpdir'/*/sd /usr/local/bin/sd"
  rm -rf "$tmpdir"
  success "sd installed"
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
  success "Theme applied: $theme"
}

finish_installation() {
  log "Installation complete."
  warn "Open a new terminal to load the updated PATH and aliases."

  if [[ "$REQUIRES_REBOOT" == "true" ]]; then
    warn "Reboot the computer before using Samba/Nautilus Share. Logoff/login is not enough."
  fi
}
