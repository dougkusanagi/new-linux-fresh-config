#!/usr/bin/env bash

section "GNOME Tweaks"
log "Configuring Flameshot shortcut and screenshot portal permission..."
if [[ "$DRY_RUN" == "true" ]]; then
  log "[DRY-RUN] Would configure Flameshot GNOME shortcut and screenshot portal permission"
  return
fi

set_screenshot_portal_permission() {
  local app_id="$1"

  if command_exists flatpak; then
    if flatpak permission-set screenshot screenshot "$app_id" yes; then
      return
    fi

    warn "flatpak could not set screenshot portal permission for $app_id; trying DBus directly"
  fi

  if command_exists busctl && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    if busctl --user call \
      org.freedesktop.impl.portal.PermissionStore \
      /org/freedesktop/impl/portal/PermissionStore \
      org.freedesktop.impl.portal.PermissionStore \
      SetPermission sbssas screenshot true screenshot "$app_id" 1 yes; then
      return
    fi
  fi

  warn "Could not configure screenshot portal permission for $app_id; no flatpak or user DBus busctl available"
}

existing_bindings="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)"
target_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom-flameshot/"

if [[ "$existing_bindings" != *"$target_path"* ]]; then
  if [[ "$existing_bindings" == "[]" || "$existing_bindings" == "@as []" ]]; then
    new_bindings="['$target_path']"
  else
    new_bindings="${existing_bindings%]}"
    new_bindings="${new_bindings}, '$target_path']"
  fi

  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$new_bindings"
fi

gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$target_path name 'PrintScrn'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$target_path command 'flameshot gui --delay 500'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$target_path binding 'Print'

set_screenshot_portal_permission org.flameshot.Flameshot
set_screenshot_portal_permission flameshot

success "Flameshot shortcut and screenshot portal permission configured"
