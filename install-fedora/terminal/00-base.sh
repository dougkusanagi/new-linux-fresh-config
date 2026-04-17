#!/usr/bin/env bash

section "Base Tools"
dnf_update

dnf_install \
  bat \
  bottom \
  fd-find \
  git \
  curl \
  wget \
  gnupg2 \
  ca-certificates \
  ripgrep \
  tealdeer \
  jq \
  xsel \
  unzip \
  dnf-plugins-core

if ! command_exists gh; then
  log "Configuring GitHub CLI repository..."
  run_quiet sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
  dnf_update
  dnf_install gh
else
  log "gh is already installed."
fi

log "Installing eza..."
dnf_install eza
add_line_if_missing 'alias ls="eza"' "$TARGET_HOME/.bashrc"
add_line_if_missing 'alias bottom="btm"' "$TARGET_HOME/.bashrc"
success "Shell aliases configured: ls, bottom"

install_sd
install_dust

dnf_install podman
sudo mkdir -p /etc/containers/registries.conf.d
sudo tee /etc/containers/registries.conf.d/00-shortnames.conf > /dev/null <<'EOF'
unqualified-search-registries = ["docker.io", "quay.io"]
short-name-mode = "permissive"
EOF
success "Podman short-name registries configured"

if command -v bun >/dev/null 2>&1; then
  log "Bun is already available."
else
  run_quiet bash -lc 'curl -fsSL https://bun.sh/install | bash'
  success "Bun installed"
fi

if command -v uv >/dev/null 2>&1; then
  log "uv is already available."
else
  run_quiet sh -lc 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  success "uv installed"
fi
