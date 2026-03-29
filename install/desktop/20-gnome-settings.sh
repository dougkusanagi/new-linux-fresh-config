#!/usr/bin/env bash

log "Configuring Flameshot shortcut..."
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
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$target_path command 'flameshot gui'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$target_path binding 'Print'
