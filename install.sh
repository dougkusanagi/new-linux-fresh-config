#!/usr/bin/env bash

set -Eeuo pipefail

RUNNING_GNOME="false"
GNOME_SETTINGS_CHANGED="false"

SKIP_SNAP="false"
SKIP_FLATPAK="false"
SKIP_DESKTOP="false"
SKIP_GSETTINGS="false"
SKIP_SYSTEMCTL="false"
SKIP_MYSQL="false"

MYSQL_ALLOW_EMPTY_ROOT_PASSWORD="false"
MYSQL_ROOT_PASSWORD=""

log() {
  echo "[INFO] $*"
}

warn() {
  echo "[AVISO] $*" >&2
}

error() {
  echo "[ERRO] $*" >&2
}

cleanup() {
  if [[ "${RUNNING_GNOME}" == "true" && "${GNOME_SETTINGS_CHANGED}" == "true" && "${SKIP_GSETTINGS}" != "true" ]]; then
    log "Restaurando configurações do GNOME..."
    gsettings set org.gnome.desktop.screensaver lock-enabled true || true
    gsettings set org.gnome.desktop.session idle-delay 300 || true
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
Uso:
  ./install.sh [flags]

Flags:
  --cli-only
      Pula tudo que for desktop/GUI/GNOME/Flatpak/Snap.

  --skip-snap
      Não instala nem configura snapd.

  --skip-flatpak
      Não instala nem configura Flatpak.

  --skip-desktop
      Não instala apps desktop nem ajustes visuais.

  --skip-gsettings
      Não executa comandos gsettings.

  --skip-systemctl
      Não executa systemctl.

  --skip-mysql
      Não instala nem configura MySQL.

  --allow-empty-mysql-root-password
      Configura o root do MySQL com senha vazia.

  --mysql-root-password=VALOR
      Configura a senha do root do MySQL com o valor informado.

  --help
      Mostra esta ajuda.
EOF
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --cli-only)
        SKIP_SNAP="true"
        SKIP_FLATPAK="true"
        SKIP_DESKTOP="true"
        SKIP_GSETTINGS="true"
        ;;
      --skip-snap)
        SKIP_SNAP="true"
        ;;
      --skip-flatpak)
        SKIP_FLATPAK="true"
        ;;
      --skip-desktop)
        SKIP_DESKTOP="true"
        ;;
      --skip-gsettings)
        SKIP_GSETTINGS="true"
        ;;
      --skip-systemctl)
        SKIP_SYSTEMCTL="true"
        ;;
      --skip-mysql)
        SKIP_MYSQL="true"
        ;;
      --allow-empty-mysql-root-password)
        MYSQL_ALLOW_EMPTY_ROOT_PASSWORD="true"
        ;;
      --mysql-root-password=*)
        MYSQL_ROOT_PASSWORD="${arg#*=}"
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        error "Flag desconhecida: $arg"
        echo
        usage
        exit 1
        ;;
    esac
  done
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

flatpak_install_app() {
  local app_id="$1"

  if [[ "${SKIP_FLATPAK}" == "true" ]]; then
    log "Pulando Flatpak: $app_id"
    return
  fi

  if flatpak info "$app_id" >/dev/null 2>&1; then
    log "Atualizando Flatpak: $app_id"
    flatpak update -y "$app_id"
  else
    log "Instalando Flatpak: $app_id"
    flatpak install -y flathub "$app_id"
  fi
}

add_path_line_if_missing() {
  local line="$1"
  local file="$2"

  touch "$file"

  if ! grep -Fqx "$line" "$file"; then
    echo "$line" >> "$file"
  fi
}

install_base_packages() {
  log "Atualizando lista de pacotes..."
  sudo apt-get update -y

  log "Instalando pacotes básicos..."
  apt_install \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    wget \
    curl \
    git \
    jq \
    xsel \
    unzip
}

detect_desktop() {
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]]; then
    RUNNING_GNOME="true"
  else
    RUNNING_GNOME="false"
  fi
}

configure_gnome_before_install() {
  if [[ "${SKIP_GSETTINGS}" == "true" ]]; then
    log "Pulando ajustes de gsettings."
    return
  fi

  if [[ "${RUNNING_GNOME}" == "true" ]]; then
    log "Desabilitando bloqueio e suspensão automática do GNOME durante a instalação..."
    gsettings set org.gnome.desktop.screensaver lock-enabled false
    gsettings set org.gnome.desktop.session idle-delay 0
    GNOME_SETTINGS_CHANGED="true"
  else
    log "Ambiente GNOME não detectado, pulando ajustes de desktop."
  fi
}

install_restricted_and_fonts() {
  log "Instalando codecs e extras..."
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y ubuntu-restricted-extras || warn "Falha ao instalar ubuntu-restricted-extras."
}

install_snapd() {
  if [[ "${SKIP_SNAP}" == "true" ]]; then
    log "Pulando snapd."
    return
  fi

  log "Instalando snapd..."
  apt_install snapd
}

install_universe_and_appimage_support() {
  log "Habilitando repositório universe..."
  sudo add-apt-repository -y universe
  sudo apt-get update -y

  log "Instalando suporte a AppImage..."
  apt_install libfuse2t64 || warn "libfuse2t64 não disponível nesta versão."
}

install_flatpak() {
  if [[ "${SKIP_FLATPAK}" == "true" ]]; then
    log "Pulando Flatpak."
    return
  fi

  log "Instalando Flatpak..."
  apt_install flatpak

  if [[ "${RUNNING_GNOME}" == "true" && "${SKIP_DESKTOP}" != "true" ]]; then
    apt_install gnome-software-plugin-flatpak
  fi

  log "Configurando Flathub..."
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

install_github_cli() {
  log "Instalando GitHub CLI..."

  if ! command_exists wget; then
    apt_install wget
  fi

  sudo mkdir -p -m 755 /etc/apt/keyrings

  local keyring_tmp
  keyring_tmp="$(mktemp)"

  wget -nv -O "$keyring_tmp" https://cli.github.com/packages/githubcli-archive-keyring.gpg
  sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg < "$keyring_tmp" > /dev/null
  rm -f "$keyring_tmp"

  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

  sudo apt-get update -y
  apt_install gh
}

install_gnome_tweaks() {
  if [[ "${SKIP_DESKTOP}" == "true" ]]; then
    log "Pulando gnome-tweaks."
    return
  fi

  if [[ "${RUNNING_GNOME}" == "true" ]]; then
    log "Instalando gnome-tweaks..."
    apt_install gnome-tweaks
  fi
}

install_podman() {
  log "Instalando Podman..."
  sudo apt-get update -y
  apt_install podman

  log "Configurando Podman para usar short names..."
  sudo mkdir -p /etc/containers/registries.conf.d
  sudo tee /etc/containers/registries.conf.d/00-shortnames.conf > /dev/null <<'EOF'
unqualified-search-registries = ["docker.io", "quay.io"]
short-name-mode = "permissive"
EOF
}

install_podman_desktop() {
  if [[ "${SKIP_DESKTOP}" == "true" || "${SKIP_FLATPAK}" == "true" ]]; then
    log "Pulando Podman Desktop."
    return
  fi

  log "Instalando Podman Desktop via Flatpak..."
  flatpak_install_app "io.podman_desktop.PodmanDesktop"
}

install_desktop_apps() {
  if [[ "${SKIP_DESKTOP}" == "true" ]]; then
    log "Pulando apps desktop."
    return
  fi

  log "Instalando apps desktop..."

  apt_install timeshift flameshot

  flatpak_install_app "org.qbittorrent.qBittorrent"
  flatpak_install_app "io.github.zen_browser.zen"
  flatpak_install_app "md.obsidian.Obsidian"
  flatpak_install_app "com.discordapp.Discord"
  flatpak_install_app "com.stremio.Stremio"
  flatpak_install_app "io.missioncenter.MissionCenter"
}

install_zed() {
  if [[ "${SKIP_DESKTOP}" == "true" ]]; then
    log "Pulando Zed."
    return
  fi

  if command_exists zed; then
    log "Zed já está instalado."
    return
  fi

  log "Instalando Zed..."
  curl -f https://zed.dev/install.sh | sh
}

install_bun() {
  if command_exists bun; then
    log "Bun já está instalado."
    return
  fi

  log "Instalando Bun..."
  curl -fsSL https://bun.sh/install | bash
}

install_uv() {
  if command_exists uv; then
    log "uv já está instalado."
    return
  fi

  log "Instalando uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
}

install_php_and_mysql() {
  log "Instalando PHP e dependências..."
  sudo apt-get update -y

  local packages=(
    php
    php-cli
    php-fpm
    php-common
    php-mbstring
    php-xml
    php-curl
    php-gd
    php-imagick
    php-zip
    php-bcmath
    php-intl
    php-mysql
    php-pgsql
    php-sqlite3
    php-redis
    php-opcache
    php-soap
  )

  if [[ "${SKIP_MYSQL}" != "true" ]]; then
    packages+=(mysql-server)
  fi

  apt_install "${packages[@]}"
}

configure_mysql() {
  if [[ "${SKIP_MYSQL}" == "true" ]]; then
    log "Pulando configuração do MySQL."
    return
  fi

  if ! command_exists mysql; then
    warn "MySQL não encontrado, pulando configuração."
    return
  fi

  if [[ "${SKIP_SYSTEMCTL}" != "true" ]]; then
    log "Habilitando e iniciando MySQL..."
    sudo systemctl enable mysql || true
    sudo systemctl start mysql || true
  else
    log "Pulando systemctl para MySQL."
  fi

  if [[ "${MYSQL_ALLOW_EMPTY_ROOT_PASSWORD}" == "true" ]]; then
    log "Configurando root do MySQL sem senha..."
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; FLUSH PRIVILEGES;" \
      || warn "Não foi possível configurar root sem senha."
    return
  fi

  if [[ -n "${MYSQL_ROOT_PASSWORD}" ]]; then
    log "Configurando senha do root do MySQL..."
    sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;" \
      || warn "Não foi possível configurar a senha do root."
    return
  fi

  warn "MySQL instalado sem alteração de senha do root."
}

install_composer() {
  if command_exists composer; then
    log "Composer já está instalado."
    return
  fi

  log "Instalando Composer..."
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php composer-setup.php
  sudo mv composer.phar /usr/local/bin/composer
  rm -f composer-setup.php
}

configure_shell_paths() {
  log "Configurando PATH no .bashrc..."

  add_path_line_if_missing 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"
  add_path_line_if_missing 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' "$HOME/.bashrc"
  add_path_line_if_missing 'export PATH="$HOME/.cargo/bin:$PATH"' "$HOME/.bashrc"
  add_path_line_if_missing 'export PATH="$HOME/.bun/bin:$PATH"' "$HOME/.bashrc"

  export PATH="$HOME/.local/bin:$HOME/.config/composer/vendor/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
}

install_valet_prerequisites() {
  log "Instalando pré-requisitos do Valet..."
  apt_install network-manager libnss3-tools jq xsel
}

install_valet() {
  if ! command_exists composer; then
    warn "Composer não encontrado, pulando instalação do Valet."
    return
  fi

  log "Instalando valet-linux..."
  composer global require cpriego/valet-linux

  warn "O valet-linux foi instalado. Talvez você ainda precise rodar manualmente:"
  warn "  valet install"
}

main() {
  parse_args "$@"

  echo "This is a very opinionated basic dev environment with PHP, Composer, Node, Valet and many desktop apps"
  echo
  echo "Begin installation (or abort with ctrl+c)..."

  require_sudo
  detect_desktop
  install_base_packages
  configure_gnome_before_install

  if [[ "${RUNNING_GNOME}" == "true" && "${SKIP_DESKTOP}" != "true" ]]; then
    log "Instalando ferramentas de terminal e desktop..."
  else
    log "Instalando ferramentas compatíveis com ambiente CLI/container..."
  fi

  install_restricted_and_fonts
  install_snapd
  install_universe_and_appimage_support
  install_flatpak
  install_github_cli
  install_gnome_tweaks
  install_podman
  install_podman_desktop
  install_desktop_apps
  install_zed
  install_bun
  install_uv
  install_php_and_mysql
  configure_mysql
  install_composer
  configure_shell_paths
  install_valet_prerequisites
  install_valet

  log "Instalação concluída."
  warn "Abra um novo terminal para garantir que todas as variáveis de PATH sejam carregadas."
}

main "$@"
