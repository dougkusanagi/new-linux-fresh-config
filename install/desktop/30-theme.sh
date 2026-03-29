#!/usr/bin/env bash

if [[ -n "${SELECTED_THEME:-}" ]]; then
  apply_selected_theme "$SELECTED_THEME"
fi
