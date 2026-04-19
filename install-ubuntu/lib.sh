#!/usr/bin/env bash

RUNNING_GNOME="false"
GNOME_SETTINGS_CHANGED="false"
REQUIRES_REBOOT="false"
DRY_RUN="${DRY_RUN:-false}"
TARGET_USER="${USER}"
TARGET_HOME="${HOME}"

runUnlessDry() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would run: $*"
    return
  fi
  "$@"
}
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
  log_to_file "INFO" "$*"
}

success() {
  printf "%sOK%s %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$*"
  log_to_file "OK" "$*"
}

warn() {
  printf "%sWARN%s %s\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$*" >&2
  log_to_file "WARN" "$*"
}

error() {
  printf "%sERROR%s %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$*" >&2
  log_to_file "ERROR" "$*"
}

log_to_file() {
  local level="$1"
  local message="$2"
  if [[ -n "${INSTALL_LOG:-}" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$INSTALL_LOG"
  fi
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
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would run: $*"
    return 0
  fi

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
  if [[ "$DRY_RUN" == "true" ]]; then
    return
  fi

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

apt_package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

apt_update() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would update package index"
    return
  fi
  run_quiet sudo apt-get update -y
  success "Package index updated"
}

apt_install() {
  local packages=("$@")
  local missing_packages=()
  local package

  for package in "${packages[@]}"; do
    if apt_package_installed "$package"; then
      log "$package is already installed."
    else
      log "Installing $package..."
      missing_packages+=("$package")
    fi
  done

  if [[ "${#missing_packages[@]}" -eq 0 ]]; then
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would install: ${missing_packages[*]}"
    return
  fi

  run_quiet sudo apt-get install -y "${missing_packages[@]}"

  for package in "${missing_packages[@]}"; do
    success "$package installed"
  done
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

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would ensure line exists in $file: $line"
    return
  fi

  touch "$file"

  if ! grep -Fqx "$line" "$file"; then
    echo "$line" >> "$file"
  fi
}

flatpak_install_app() {
  local app_id="$1"

  if [[ "$DRY_RUN" == "true" ]]; then
    if flatpak info "$app_id" >/dev/null 2>&1; then
      log "[DRY-RUN] Would update flatpak: $app_id"
    else
      log "[DRY-RUN] Would install flatpak: $app_id"
    fi
    return
  fi

  if flatpak info "$app_id" >/dev/null 2>&1; then
    run_quiet flatpak update -y "$app_id"
    success "Flatpak updated: $app_id"
  else
    run_quiet flatpak install -y flathub "$app_id"
    success "Flatpak installed: $app_id"
  fi
}

download_file() {
  local url="$1"
  local destination="$2"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would download $url to $destination"
    return
  fi

  mkdir -p "$(dirname "$destination")"
  curl -fsSL "$url" -o "$destination"
}

github_latest_asset_url() {
  local repo="$1"
  local pattern="$2"

  curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | jq -r --arg pattern "$pattern" '.assets[] | select(.name | test($pattern)) | .browser_download_url' \
    | head -n 1
}

install_npm_global_package() {
  local command_name="$1"
  local package_name="$2"

  if command_exists "$command_name"; then
    log "$command_name is already available."
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would install npm package globally: $package_name"
    return
  fi

  if ! command_exists npm; then
    error "npm is required to install $package_name."
    return 1
  fi

  run_quiet sudo npm install -g "$package_name"
  success "$command_name installed"
}

install_dust() {
  if command_exists dust; then
    log "dust is already available."
    return
  fi

  run_quiet bash -lc 'curl -sSfL https://raw.githubusercontent.com/bootandy/dust/refs/heads/master/install.sh | sh'
  success "dust installed"
}

install_lazygit() {
  if command_exists lazygit; then
    log "lazygit is already available."
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would install lazygit from GitHub releases"
    return
  fi

  local asset_arch tmpdir url
  case "$(uname -m)" in
    x86_64|amd64)
      asset_arch="x86_64"
      ;;
    aarch64|arm64)
      asset_arch="arm64"
      ;;
    *)
      error "Unsupported lazygit architecture: $(uname -m)"
      return 1
      ;;
  esac

  url="$(github_latest_asset_url "jesseduffield/lazygit" "linux_${asset_arch}\\.tar\\.gz$")"
  if [[ -z "$url" ]]; then
    error "Could not find a lazygit release asset for linux_${asset_arch}."
    return 1
  fi

  tmpdir="$(mktemp -d)"
  run_quiet bash -lc "curl -sSfL '$url' | tar xz -C '$tmpdir' lazygit && sudo install -m 0755 '$tmpdir/lazygit' /usr/local/bin/lazygit"
  rm -rf "$tmpdir"
  success "lazygit installed"
}

install_atuin() {
  if command_exists atuin; then
    log "atuin is already available."
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would install atuin from GitHub releases"
    return
  fi

  local target tmpdir url binary
  case "$(uname -m)" in
    x86_64|amd64)
      target="x86_64-unknown-linux-gnu"
      ;;
    aarch64|arm64)
      target="aarch64-unknown-linux-gnu"
      ;;
    *)
      error "Unsupported atuin architecture: $(uname -m)"
      return 1
      ;;
  esac

  url="$(github_latest_asset_url "atuinsh/atuin" "atuin-${target}\\.tar\\.gz$")"
  if [[ -z "$url" ]]; then
    error "Could not find an atuin release asset for $target."
    return 1
  fi

  tmpdir="$(mktemp -d)"
  run_quiet bash -lc "curl -sSfL '$url' | tar xz -C '$tmpdir'"
  binary="$(find "$tmpdir" -type f -name atuin -perm /111 | head -n 1)"
  if [[ -z "$binary" ]]; then
    rm -rf "$tmpdir"
    error "Could not find the atuin binary in the release archive."
    return 1
  fi
  run_quiet sudo install -m 0755 "$binary" /usr/local/bin/atuin
  rm -rf "$tmpdir"
  success "atuin installed"
}

install_yazi() {
  if command_exists yazi && command_exists ya; then
    log "yazi is already available."
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would install yazi from GitHub releases"
    return
  fi

  local target tmpdir url yazi_binary ya_binary
  case "$(uname -m)" in
    x86_64|amd64)
      target="x86_64-unknown-linux-gnu"
      ;;
    aarch64|arm64)
      target="aarch64-unknown-linux-gnu"
      ;;
    *)
      error "Unsupported yazi architecture: $(uname -m)"
      return 1
      ;;
  esac

  url="$(github_latest_asset_url "sxyazi/yazi" "yazi-${target}\\.zip$")"
  if [[ -z "$url" ]]; then
    error "Could not find a yazi release asset for $target."
    return 1
  fi

  tmpdir="$(mktemp -d)"
  run_quiet bash -lc "curl -sSfL '$url' -o '$tmpdir/yazi.zip' && unzip -q '$tmpdir/yazi.zip' -d '$tmpdir'"
  yazi_binary="$(find "$tmpdir" -type f -name yazi -perm /111 | head -n 1)"
  ya_binary="$(find "$tmpdir" -type f -name ya -perm /111 | head -n 1)"
  if [[ -z "$yazi_binary" || -z "$ya_binary" ]]; then
    rm -rf "$tmpdir"
    error "Could not find yazi and ya binaries in the release archive."
    return 1
  fi
  run_quiet sudo install -m 0755 "$yazi_binary" /usr/local/bin/yazi
  run_quiet sudo install -m 0755 "$ya_binary" /usr/local/bin/ya
  rm -rf "$tmpdir"
  success "yazi installed"
}

install_opencode_desktop() {
  if apt_package_installed opencode-desktop || command_exists opencode-desktop; then
    log "OpenCode Desktop is already installed."
    return
  fi

  case "$(uname -m)" in
    x86_64|amd64)
      ;;
    *)
      error "OpenCode Desktop Linux package is only available for x86_64 from opencode.ai."
      return 1
      ;;
  esac

  local package_file="/tmp/opencode-desktop.deb"
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would install OpenCode Desktop from https://opencode.ai/download/stable/linux-x64-deb"
    return
  fi

  download_file "https://opencode.ai/download/stable/linux-x64-deb" "$package_file"
  run_quiet sudo apt-get install -y "$package_file"
  rm -f "$package_file"
  success "OpenCode Desktop installed"
}

detect_desktop() {
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]]; then
    RUNNING_GNOME="true"
  fi
}

configure_gnome_for_install() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would disable GNOME auto-lock and suspend"
    GNOME_SETTINGS_CHANGED="false"
    return
  fi
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

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would download and apply theme: $theme"
    return
  fi

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
