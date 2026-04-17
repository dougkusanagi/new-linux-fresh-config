#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="$ROOT_DIR/install-fedora"
SELECTED_THEME=""
export SELECTED_THEME

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--theme=NAME] [--list-themes] [--help]

Options:
  --theme=NAME
      Apply one of the Omakub-inspired themes after desktop installation.

  --list-themes
      List supported themes and exit.

  --help
      Show this help.
EOF
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
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

# shellcheck source=/dev/null
source "$INSTALL_ROOT/lib.sh"

trap cleanup EXIT

main() {
  parse_args "$@"

  if [[ "${EUID}" -eq 0 ]]; then
    error "Execute este script com seu usuario normal, sem sudo."
    exit 1
  fi

  echo "This is a very opinionated basic dev environment with PHP, Composer, Node and many desktop apps"
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
