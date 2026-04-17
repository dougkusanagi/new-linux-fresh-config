#!/usr/bin/env bash

section "Desktop Core"

dnf_update
dnf_install_optional fuse

dnf_install flatpak
run_quiet sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
if flatpak remotes --user | grep -q "^flathub"; then
  run_quiet flatpak remote-delete --user --force flathub 2>/dev/null || true
fi
success "Flathub configured"

dnf_install gnome-tweaks flameshot
dnf_install_optional timeshift

dnf_install samba samba-client
getent group sambashare >/dev/null 2>&1 || run_quiet sudo groupadd -r sambashare
run_quiet sudo usermod -aG sambashare "$TARGET_USER"
success "User added to sambashare: $TARGET_USER"
sudo mkdir -p /var/lib/samba/usershares
sudo chown root:sambashare /var/lib/samba/usershares
sudo chmod 1770 /var/lib/samba/usershares
success "Samba usershare directory configured"

if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl restart smb
  success "smb restarted"
else
  warn "systemctl is not available. Restart smb manually if needed."
fi

mark_reboot_required
