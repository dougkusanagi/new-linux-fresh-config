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
MULTIPASS_CERT_PATH="/var/snap/multipass/common/data/multipassd/multipass_root_cert.pem"

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

run_quiet() {
  local log_file exit_code
  log_file="$(mktemp)"

  if "$@" >"$log_file" 2>&1; then
    rm -f "$log_file"
    return 0
  fi

  exit_code=$?
  error "Command failed: $*"
  sed -n '1,120p' "$log_file" >&2 || true
  rm -f "$log_file"
  return "$exit_code"
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

check_multipass_host_prereqs() {
  local resolv_target
  resolv_target="$(readlink -f /etc/resolv.conf 2>/dev/null || true)"

  if [[ "$resolv_target" == /opt/valet-linux/* ]]; then
    error "Multipass cannot start while /etc/resolv.conf points to Valet Linux: $resolv_target"
    warn "Your current DNS servers from NetworkManager are:"
    nmcli dev show 2>/dev/null | rg 'IP4.DNS|IP6.DNS' >&2 || true
    warn "Temporarily replace /etc/resolv.conf with a regular file, then retry ./test.sh."
    warn "Example:"
    warn "  sudo rm -f /etc/resolv.conf"
    warn "  printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' | sudo tee /etc/resolv.conf >/dev/null"
    warn "After testing, restore the Valet setup if you still need it."
    exit 1
  fi
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
    if multipass_ready; then
      success "Multipass is already ready"
      return
    fi

    start_multipass_daemon
    wait_for_multipass_ready
    return
  fi

  if ! command_exists snap; then
    error "Multipass is not installed and snap is not available to install it."
    exit 1
  fi

  log "Installing Multipass via snap..."
  run_quiet sudo snap install multipass
  success "Multipass installed"
  start_multipass_daemon
  wait_for_multipass_ready
}

start_multipass_daemon() {
  if multipass_ready; then
    log "Multipass daemon is already running."
    return
  fi

  log "Ensuring the Multipass daemon is running..."
  sudo snap start multipass.multipassd >/dev/null 2>&1 \
    || sudo snap restart multipass.multipassd >/dev/null 2>&1 \
    || true
}

multipass_ready() {
  local service_state

  service_state="$(
    snap services multipass 2>/dev/null \
      | awk 'NR > 1 {print $3}' \
      | head -n 1
  )"

  [[ "$service_state" == "active" ]] \
    && [[ -f "$MULTIPASS_CERT_PATH" ]] \
    && multipass find >/dev/null 2>&1
}

do_launch_vm() {
  run_quiet multipass launch "$VM_RELEASE" \
    --name "$VM_NAME" \
    --cpus "$VM_CPUS" \
    --memory "$VM_MEMORY" \
    --disk "$VM_DISK"
}

wait_for_multipass_ready() {
  local attempt max_attempts
  max_attempts=30

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if multipass_ready; then
      success "Multipass is ready"
      return
    fi

    sleep 2
  done

  error "Multipass did not become ready after installation/startup."
  snap services multipass >&2 || true
  warn "Try running: sudo snap restart multipass.multipassd"
  exit 1
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
  section "Container Test"
  detect_container_engine

  log "Using container engine: $CONTAINER_ENGINE"
  log "Using image: $CONTAINER_IMAGE"
  warn "Container mode is a smoke test only. It does not validate GNOME, Nautilus Share, themes, or reboot."

  container_cleanup

  run_quiet "$CONTAINER_ENGINE" run --name "$CONTAINER_NAME" --rm \
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
  success "Container smoke test completed"
}

launch_vm() {
  if vm_exists; then
    log "Deleting existing VM '$VM_NAME' before re-creating it..."
    multipass delete --purge "$VM_NAME" >/dev/null 2>&1 || multipass delete "$VM_NAME" >/dev/null 2>&1 || true
  fi

  log "Refreshing Multipass image catalog..."
  run_quiet multipass find || true

  log "Launching Ubuntu $VM_RELEASE VM '$VM_NAME'..."
  if ! do_launch_vm; then
    warn "First launch attempt failed. Refreshing catalog and retrying once..."
    if vm_exists; then
      multipass delete --purge "$VM_NAME" >/dev/null 2>&1 || multipass delete "$VM_NAME" >/dev/null 2>&1 || true
    fi
    run_quiet multipass find || true
    do_launch_vm
  fi
  success "VM launched: $VM_NAME"
}

mount_workspace() {
  log "Mounting repository into the VM..."
  run_quiet multipass exec "$VM_NAME" -- mkdir -p "$VM_WORKDIR"
  run_quiet multipass mount "$PWD" "$VM_NAME:$VM_WORKDIR"
  success "Repository mounted in VM"
}

run_vm_test() {
  section "Multipass Test"
  check_multipass_host_prereqs
  ensure_multipass
  warn "Multipass mode validates a clean Ubuntu VM and the CLI path of the installer."
  warn "For GNOME, Nautilus Share, Samba reboot, fonts, and themes, follow the manual desktop checklist in test-vm.md."

  launch_vm
  mount_workspace

  section "VM Bootstrap"
  run_quiet multipass exec "$VM_NAME" -- bash -lc "
    set -Eeuo pipefail
    export DEBIAN_FRONTEND=noninteractive

    cd '$VM_WORKDIR'

    sudo apt-get update
    sudo apt-get install -y bash ca-certificates curl git jq sudo wget software-properties-common xsel unzip fontconfig
  "
  success "Bootstrap packages ready in VM"

  log "Validating installer syntax in VM..."
  run_quiet multipass exec "$VM_NAME" -- bash -lc "
    set -Eeuo pipefail
    cd '$VM_WORKDIR'
    bash -n '$SCRIPT_NAME' install/lib.sh install/terminal.sh install/desktop.sh install/terminal/*.sh install/desktop/*.sh
  "
  success "Installer syntax validated"

  log "Validating theme list in VM..."
  run_quiet multipass exec "$VM_NAME" -- bash -lc "
    set -Eeuo pipefail
    cd '$VM_WORKDIR'
    ./'$SCRIPT_NAME' --list-themes >/dev/null
  "
  success "Theme list validated"

  section "Installer"
  multipass exec "$VM_NAME" -- bash -lc "
    set -Eeuo pipefail
    cd '$VM_WORKDIR'
    chmod +x '$SCRIPT_NAME'
    ./'$SCRIPT_NAME'
  "
  success "Installer completed in VM"
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
