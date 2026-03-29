#!/usr/bin/env bash

log "Installing desktop prerequisites..."
apt_install snapd

sudo add-apt-repository -y universe
sudo apt-get update -y
apt_install libfuse2t64 || warn "libfuse2t64 is not available on this distribution."

log "Installing Flatpak..."
apt_install flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

log "Installing GNOME tools..."
apt_install gnome-tweaks timeshift flameshot

log "Installing Samba and Nautilus Share..."
apt_install samba nautilus-share
sudo adduser "$TARGET_USER" sambashare
sudo mkdir -p /var/lib/samba/usershares
sudo chown root:sambashare /var/lib/samba/usershares
sudo chmod 1770 /var/lib/samba/usershares

if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl restart smbd
else
  warn "systemctl is not available. Restart smbd manually if needed."
fi

mark_reboot_required
