#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUESTED_DISTRO="auto"
DRY_RUN="false"
INSTALL_FAMILY=""
INSTALL_ROOT=""
SELECTED_THEME=""
export SELECTED_THEME

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--distro=auto|ubuntu|fedora|nobara] [--theme=NAME] [--list-themes] [--help]

Options:
  --distro=NAME
      Select installer family. Default: auto.

  --dry-run
      Show what would be installed without making any changes.

  --theme=NAME
      Apply one of the Omakub-inspired themes after desktop installation.

  --list-themes
      List supported themes and exit.

  --help
      Show this help.
EOF
}

normalize_local_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

preparse_args() {
  for arg in "$@"; do
    case "$arg" in
      --distro=*)
        REQUESTED_DISTRO="$(normalize_local_name "${arg#*=}")"
        ;;
      --dry-run)
        DRY_RUN="true"
        ;;
      --help)
        usage
        exit 0
        ;;
    esac
  done
}

detect_install_family() {
  local requested="$1"

  case "$requested" in
    auto)
      ;;
    ubuntu)
      INSTALL_FAMILY="ubuntu"
      INSTALL_ROOT="$ROOT_DIR/install-ubuntu"
      return
      ;;
    fedora|nobara)
      INSTALL_FAMILY="fedora"
      INSTALL_ROOT="$ROOT_DIR/install-fedora"
      return
      ;;
    *)
      echo "Unsupported distro: $requested" >&2
      echo "Supported values: auto, ubuntu, fedora, nobara" >&2
      exit 1
      ;;
  esac

  if [[ ! -r /etc/os-release ]]; then
    echo "Could not detect distro because /etc/os-release is not readable." >&2
    echo "Retry with --distro=ubuntu, --distro=fedora, or --distro=nobara." >&2
    exit 1
  fi

  # shellcheck source=/dev/null
  source /etc/os-release

  case "${ID:-}" in
    ubuntu)
      INSTALL_FAMILY="ubuntu"
      INSTALL_ROOT="$ROOT_DIR/install-ubuntu"
      ;;
    fedora|nobara)
      INSTALL_FAMILY="fedora"
      INSTALL_ROOT="$ROOT_DIR/install-fedora"
      ;;
    *)
      if [[ " ${ID_LIKE:-} " == *" debian "* ]]; then
        INSTALL_FAMILY="ubuntu"
        INSTALL_ROOT="$ROOT_DIR/install-ubuntu"
      elif [[ " ${ID_LIKE:-} " == *" fedora "* ]]; then
        INSTALL_FAMILY="fedora"
        INSTALL_ROOT="$ROOT_DIR/install-fedora"
      else
        echo "Unsupported distro: ${PRETTY_NAME:-${ID:-unknown}}" >&2
        echo "Retry with --distro=ubuntu, --distro=fedora, or --distro=nobara if you know it is compatible." >&2
        exit 1
      fi
      ;;
  esac
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --distro=*)
        ;;
      --dry-run)
        ;;
      --theme=*)
        SELECTED_THEME="$(normalize_theme_name "${arg#*=}")"
        ;;
      --list-themes)
        list_supported_themes
        exit 0
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $arg"
        echo
        usage
        exit 1
        ;;
    esac
  done
}

trap 'echo "A instalacao falhou. Voce pode tentar novamente com: ./install.sh"' ERR

preparse_args "$@"
detect_install_family "$REQUESTED_DISTRO"

log_to_file() {
  local level="$1"
  local message="$2"
  if [[ -n "${INSTALL_LOG:-}" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$INSTALL_LOG"
  fi
}

export DRY_RUN

# shellcheck source=/dev/null
source "$INSTALL_ROOT/lib.sh"

trap cleanup EXIT

main() {
  parse_args "$@"

  if [[ "${EUID}" -eq 0 ]]; then
    error "Execute este script com seu usuario normal, sem sudo."
    exit 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "Running in DRY-RUN mode - no changes will be made"
    echo
  fi

  export INSTALL_LOG="$ROOT_DIR/install-$(date +%Y%m%d-%H%M%S).log"
  echo "Logging to: $INSTALL_LOG"
  log_to_file "INFO" "Installation started - $INSTALL_FAMILY"

  echo "This is a very opinionated basic dev environment with PHP, Composer, Node and many desktop apps"
  log "Selected installer family: $INSTALL_FAMILY"
  echo
  echo "Begin installation (or abort with ctrl+c)..."

  require_sudo
  detect_desktop

  if [[ "$RUNNING_GNOME" == "true" ]]; then
    configure_gnome_for_install
    log "Installing terminal and desktop tools..."
  else
    log "Only installing terminal tools..."
  fi

  # shellcheck source=/dev/null
  source "$INSTALL_ROOT/terminal.sh"

  if [[ "$RUNNING_GNOME" == "true" ]]; then
    # shellcheck source=/dev/null
    source "$INSTALL_ROOT/desktop.sh"
  fi

  finish_installation
}

main "$@"
