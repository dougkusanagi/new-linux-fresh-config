#!/usr/bin/env bash

section "Desktop Apps"
apt_install_optional steam-devices joystick jstest-gtk gamemode mangohud gamescope goverlay

flatpak_install_app "com.visualstudio.code"
flatpak_install_app "com.google.Chrome"
flatpak_install_app "io.podman_desktop.PodmanDesktop"
flatpak_install_app "it.mijorus.gearlever"
flatpak_install_app "org.qbittorrent.qBittorrent"
flatpak_install_app "io.github.zen_browser.zen"
flatpak_install_app "io.missioncenter.MissionCenter"
flatpak_install_app "md.obsidian.Obsidian"
flatpak_install_app "com.discordapp.Discord"
flatpak_install_app "com.ktechpit.whatsie"
flatpak_install_app "com.stremio.Stremio"
flatpak_install_app "com.github.dynobo.normcap"
flatpak_install_app "com.valvesoftware.Steam"
flatpak_install_app "net.lutris.Lutris"
flatpak_install_app "com.vysp3r.ProtonPlus"
flatpak_install_app "com.heroicgameslauncher.hgl"
flatpak_install_app "com.usebottles.bottles"
install_lm_studio
install_opencode_desktop

if command -v zed >/dev/null 2>&1; then
  log "Zed is already available."
else
  run_quiet sh -lc 'curl -f https://zed.dev/install.sh | sh'
  success "Zed installed"
fi
