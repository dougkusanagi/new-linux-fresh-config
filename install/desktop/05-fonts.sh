#!/usr/bin/env bash

FONT_SOURCE_DIR="$INSTALL_ROOT/fonts"
FONT_DEST_DIR="$TARGET_HOME/.local/share/fonts/new-linux-fresh-config"

if [[ ! -d "$FONT_SOURCE_DIR" ]]; then
  warn "Font directory not found: $FONT_SOURCE_DIR"
  return
fi

log "Installing local fonts from install/fonts..."
mkdir -p "$FONT_DEST_DIR"

while IFS= read -r -d '' font_file; do
  cp -f "$font_file" "$FONT_DEST_DIR/"
done < <(find "$FONT_SOURCE_DIR" -maxdepth 1 -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)

if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$FONT_DEST_DIR"
else
  warn "fc-cache is not available. Refresh the font cache manually if needed."
fi
