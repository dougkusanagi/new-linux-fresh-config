#!/usr/bin/env bash

set -Eeuo pipefail

MODE="multipass"
SCRIPT_NAME="install.sh"
CONTAINER_IMAGE="ubuntu:24.04"
CONTAINER_NAME="setup-script-test"
VM_NAME="fresh-config-test"
VM_RELEASE="24.04"
VM_CPUS="2"
VM_MEMORY="4G"
VM_DISK="30G"
VM_WORKDIR="/home/ubuntu/workspace"
KEEP_VM="false"

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*" >&2
}

error() {
  echo "[ERROR] $*" >&2
}

usage() {
  cat <<'EOF'
Usage:
  ./test.sh [options]

Options:
  --mode=multipass
      Default. Installs Multipass if needed, creates a clean Ubuntu VM,
      mounts the repo, and runs the installer there.

  --mode=container
      Runs a fast smoke test in a container. Useful for quick checks,
      but it does not validate GNOME, Nautilus Share, themes, or reboot flows.

  --keep-vm
      Keeps the Multipass VM after the test.

  --name=NAME
      VM or container instance name. Default: fresh-config-test

  --release=VERSION
      Ubuntu release for Multipass. Default: 24.04

  --cpus=N
      VM CPU count. Default: 2

  --memory=SIZE
      VM memory. Default: 4G

  --disk=SIZE
      VM disk. Default: 30G

  --script=FILE
      Script to run inside the guest/container. Default: install.sh

  --help
      Show this help.
EOF
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --mode=*)
        MODE="${arg#*=}"
        ;;
      --keep-vm)
        KEEP_VM="true"
        ;;
      --name=*)
        VM_NAME="${arg#*=}"
        CONTAINER_NAME="${arg#*=}"
        ;;
      --release=*)
        VM_RELEASE="${arg#*=}"
        ;;
      --cpus=*)
        VM_CPUS="${arg#*=}"
        ;;
      --memory=*)
        VM_MEMORY="${arg#*=}"
        ;;
      --disk=*)
        VM_DISK="${arg#*=}"
        ;;
      --script=*)
        SCRIPT_NAME="${arg#*=}"
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

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_script() {
  [[ -f "$SCRIPT_NAME" ]] || {
    error "File '$SCRIPT_NAME' was not found in $(pwd)."
    exit 1
  }
}

detect_container_engine() {
  if command_exists podman; then
    CONTAINER_ENGINE="podman"
  elif command_exists docker; then
    CONTAINER_ENGINE="docker"
  else
    error "Neither podman nor docker is installed."
    exit 1
  fi
}

ensure_multipass() {
  if command_exists multipass; then
    return
  fi

  if ! command_exists snap; then
    error "Multipass is not installed and snap is not available to install it."
    exit 1
  fi

  log "Installing Multipass via snap..."
  sudo snap install multipass
}

container_cleanup() {
  if [[ "${CONTAINER_ENGINE:-}" != "" ]]; then
    "$CONTAINER_ENGINE" rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
}

vm_exists() {
  multipass info "$VM_NAME" >/dev/null 2>&1
}

vm_cleanup() {
  if [[ "$KEEP_VM" == "true" ]]; then
    warn "Keeping VM '$VM_NAME' because --keep-vm was used."
    return
  fi

  if vm_exists; then
    log "Deleting VM '$VM_NAME'..."
    multipass delete --purge "$VM_NAME" >/dev/null 2>&1 || multipass delete "$VM_NAME" >/dev/null 2>&1 || true
  fi
}

cleanup() {
  if [[ "$MODE" == "container" ]]; then
    container_cleanup
  else
    vm_cleanup
  fi
}

run_container_test() {
  detect_container_engine

  log "Using container engine: $CONTAINER_ENGINE"
  log "Using image: $CONTAINER_IMAGE"
  warn "Container mode is a smoke test only. It does not validate GNOME, Nautilus Share, themes, or reboot."

  container_cleanup

  "$CONTAINER_ENGINE" run --name "$CONTAINER_NAME" --rm \
    -v "$PWD:/workspace" \
    -w /workspace \
    "$CONTAINER_IMAGE" \
    bash -lc "
      set -Eeuo pipefail
      export DEBIAN_FRONTEND=noninteractive

      apt-get update
      apt-get install -y bash ca-certificates curl git jq sudo wget software-properties-common xsel unzip fontconfig

      echo '[INFO] Validating shell syntax...'
      bash -n '$SCRIPT_NAME' install/lib.sh install/terminal.sh install/desktop.sh install/terminal/*.sh install/desktop/*.sh

      echo '[INFO] Validating theme list...'
      ./'$SCRIPT_NAME' --list-themes >/dev/null

      echo '[INFO] Executing installer inside the container...'
      chmod +x '$SCRIPT_NAME'
      ./'$SCRIPT_NAME'
    "
}

launch_vm() {
  if vm_exists; then
    log "Deleting existing VM '$VM_NAME' before re-creating it..."
    multipass delete --purge "$VM_NAME" >/dev/null 2>&1 || multipass delete "$VM_NAME" >/dev/null 2>&1 || true
  fi

  log "Launching Ubuntu $VM_RELEASE VM '$VM_NAME'..."
  multipass launch "$VM_RELEASE" \
    --name "$VM_NAME" \
    --cpus "$VM_CPUS" \
    --memory "$VM_MEMORY" \
    --disk "$VM_DISK"
}

mount_workspace() {
  log "Mounting repository into the VM..."
  multipass exec "$VM_NAME" -- mkdir -p "$VM_WORKDIR"
  multipass mount "$PWD" "$VM_NAME:$VM_WORKDIR"
}

run_vm_test() {
  ensure_multipass
  warn "Multipass mode validates a clean Ubuntu VM and the CLI path of the installer."
  warn "For GNOME, Nautilus Share, Samba reboot, fonts, and themes, follow the manual desktop checklist in test-vm.md."

  launch_vm
  mount_workspace

  multipass exec "$VM_NAME" -- bash -lc "
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive

    cd '$VM_WORKDIR'

    sudo apt-get update
    sudo apt-get install -y bash ca-certificates curl git jq sudo wget software-properties-common xsel unzip fontconfig

    echo '[INFO] Validating shell syntax...'
    bash -n '$SCRIPT_NAME' install/lib.sh install/terminal.sh install/desktop.sh install/terminal/*.sh install/desktop/*.sh

    echo '[INFO] Validating theme list...'
    ./'$SCRIPT_NAME' --list-themes >/dev/null

    echo '[INFO] Executing installer inside the Ubuntu VM...'
    chmod +x '$SCRIPT_NAME'
    ./'$SCRIPT_NAME'
  "
}

main() {
  parse_args "$@"
  require_script
  trap cleanup EXIT

  case "$MODE" in
    multipass)
      run_vm_test
      ;;
    container)
      run_container_test
      ;;
    *)
      error "Unsupported mode: $MODE"
      exit 1
      ;;
  esac
}

main "$@"
