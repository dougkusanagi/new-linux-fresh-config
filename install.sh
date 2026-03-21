#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "This is a very opinionated basic dev environment with PHP, Composer, Node, Valet and many desktop apps"
echo -e "\nBegin installation (or abort with ctrl+c)..."

echo "Updating OS..."
sudo apt-get update -y >/dev/null
sudo apt-get install -y git curl >/dev/null

# Desktop software and tweaks will only be installed if we're running Gnome
RUNNING_GNOME=$([[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]] && echo true || echo false)

if $RUNNING_GNOME; then
  # Ensure computer doesn't go to sleep or lock while installing
  gsettings set org.gnome.desktop.screensaver lock-enabled false
  gsettings set org.gnome.desktop.session idle-delay 0

  echo "Installing terminal and desktop tools..."
else
  echo "Only installing terminal tools..."
fi

# Multimedia codecs and fonts
sudo apt-get install -y ubuntu-restricted-extras

# snapd
sudo apt install -y snapd

# Necessary to open AppImage files
sudo add-apt-repository -y universe
sudo apt install -y libfuse2t64

# Flatpak installation
sudo apt install -y flatpak
sudo apt install -y gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Github CLI (gh)
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
        && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y

# Para desabilitar função de "colar" com click do botão do meio do mouse
sudo apt install gnome-tweaks

# Podman
sudo apt-get update
sudo apt-get -y install podman

# Podman Desktop
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --or-update -y --user flathub io.podman_desktop.PodmanDesktop
flatpak run io.podman_desktop.PodmanDesktop

# Configure Podman to use short names like docker
sudo mkdir -p /etc/containers/registries.conf.d
sudo tee /etc/containers/registries.conf.d/00-shortnames.conf > /dev/null <<'EOF'
unqualified-search-registries = ["docker.io", "quay.io"]
short-name-mode = "permissive"
EOF

# Timeshift
sudo apt install -y timeshift

# Flameshot
sudo apt install -y flameshot

# qBittorrent
flatpak install --or-update -y flathub org.qbittorrent.qBittorrent

# Zen Browser
flatpak install --or-update -y flathub io.github.zen_browser.zen

# Obsidian
flatpak install --or-update -y md.obsidian.Obsidian

# Discord
flatpak install --or-update -y flathub com.discordapp.Discord

# Stremio
flatpak install --or-update -y com.stremio.Stremio

# Zed Editor
curl -f https://zed.dev/install.sh | sh

# Bun
curl -fsSL https://bun.sh/install | bash

# Uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install PHP and dependencies
sudo apt update -y && \
sudo apt install -y php php-cli php-fpm php-common \
  php-mbstring php-xml php-curl php-gd php-imagick \
  php-zip php-bcmath php-intl php-mysql php-pgsql \
  php-sqlite3 php-redis php-dom php-opcache php-soap \
  mysql-server

# Enable MySQL and set root password
sudo systemctl enable mysql && \
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY ''; FLUSH PRIVILEGES;"

# Set up Composer path
echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

# Reload bashrc to apply changes
source ~/.bashrc

# Valet Prerequisites
sudo apt install -y network-manager libnss3-tools jq xsel

# Valet Install
composer global require cpriego/valet-linux

# Revert to normal idle and lock settings
gsettings set org.gnome.desktop.screensaver lock-enabled true
gsettings set org.gnome.desktop.session idle-delay 300
