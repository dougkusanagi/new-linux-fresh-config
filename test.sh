#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE="debian:bookworm-slim"
#IMAGE="ubuntu:24.04"
SCRIPT_NAME="install.sh"
WORKDIR="/workspace"
CONTAINER_NAME="setup-script-test"

log() {
  echo "[INFO] $*"
}

error() {
  echo "[ERRO] $*" >&2
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    error "Comando não encontrado: $1"
    exit 1
  }
}

detect_container_engine() {
  if command -v podman >/dev/null 2>&1; then
    CONTAINER_ENGINE="podman"
  elif command -v docker >/dev/null 2>&1; then
    CONTAINER_ENGINE="docker"
  else
    error "Nem podman nem docker estão instalados."
    exit 1
  fi
}

check_script() {
  [[ -f "$SCRIPT_NAME" ]] || {
    error "Arquivo '$SCRIPT_NAME' não encontrado na pasta atual."
    exit 1
  }
}

cleanup() {
  "$CONTAINER_ENGINE" rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}

run_test() {
  log "Usando engine: $CONTAINER_ENGINE"
  log "Usando imagem: $IMAGE"

  cleanup

  "$CONTAINER_ENGINE" run --name "$CONTAINER_NAME" --rm \
    -v "$PWD:$WORKDIR" \
    -w "$WORKDIR" \
    "$IMAGE" \
    bash -lc "
      set -Eeuo pipefail

      export DEBIAN_FRONTEND=noninteractive

      apt-get update
      apt-get install -y bash ca-certificates curl git sudo wget software-properties-common

      echo '[INFO] Validando sintaxe do script...'
      bash -n '$SCRIPT_NAME'

      echo '[INFO] Executando script dentro do container...'
      chmod +x '$SCRIPT_NAME'
      ./'$SCRIPT_NAME'
    "
}

main() {
  detect_container_engine
  check_script
  trap cleanup EXIT
  run_test
}

main \"$@\"
