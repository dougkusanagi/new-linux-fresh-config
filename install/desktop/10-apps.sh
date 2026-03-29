#!/usr/bin/env bash

log "Installing desktop apps..."
flatpak_install_app "io.podman_desktop.PodmanDesktop"
flatpak_install_app "org.qbittorrent.qBittorrent"
flatpak_install_app "io.github.zen_browser.zen"
flatpak_install_app "md.obsidian.Obsidian"
flatpak_install_app "com.discordapp.Discord"
flatpak_install_app "com.stremio.Stremio"

if command -v zed >/dev/null 2>&1; then
  log "Zed is already installed."
else
  log "Installing Zed..."
  curl -f https://zed.dev/install.sh | sh
fi
