#!/usr/bin/env bash

log "Updating OS..."
sudo apt-get update -y

log "Installing base packages..."
apt_install \
  bat \
  btm \
  fd-find \
  git \
  curl \
  wget \
  gpg \
  ca-certificates \
  ripgrep \
  sd \
  software-properties-common \
  tealdeer \
  apt-transport-https \
  jq \
  xsel \
  unzip

log "Installing GitHub CLI..."
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -nv -O /tmp/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg
cat /tmp/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
rm -f /tmp/githubcli-archive-keyring.gpg
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update -y
apt_install gh

log "Installing eza..."
sudo mkdir -p /etc/apt/keyrings
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
  | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
  | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt-get update -y
apt_install eza
add_line_if_missing 'alias ls="eza"' "$TARGET_HOME/.bashrc"
add_line_if_missing 'alias bat="batcat"' "$TARGET_HOME/.bashrc"
add_line_if_missing 'alias fd="fdfind"' "$TARGET_HOME/.bashrc"
add_line_if_missing 'alias bottom="btm"' "$TARGET_HOME/.bashrc"

install_dust

log "Installing Podman..."
apt_install podman
sudo mkdir -p /etc/containers/registries.conf.d
sudo tee /etc/containers/registries.conf.d/00-shortnames.conf > /dev/null <<'EOF'
unqualified-search-registries = ["docker.io", "quay.io"]
short-name-mode = "permissive"
EOF

if command -v bun >/dev/null 2>&1; then
  log "Bun is already installed."
else
  log "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
fi

if command -v uv >/dev/null 2>&1; then
  log "uv is already installed."
else
  log "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
