#!/usr/bin/env bash
# Telegram draws the viewer's window buttons from the desktop button layout.
# A common default is "appmenu:close" — only a close button, so there is no
# way to leave the viewer's fullscreen mode. This script adds the maximize
# button for a moment, waits for you, then puts your layout back.
set -euo pipefail

command -v gsettings >/dev/null || {
    echo "gsettings not found: add 'maximize' to your GTK decoration layout manually" >&2
    exit 1
}

key=(org.gnome.desktop.wm.preferences button-layout)
old="$(gsettings get "${key[@]}")"
restore() { gsettings set "${key[@]}" "$old"; echo "restored button layout: $old"; }
trap restore EXIT

gsettings set "${key[@]}" 'appmenu:minimize,maximize,close'
cat <<'EOF'
Maximize button enabled.
  1. Close the Telegram media viewer if it is open, then open any photo.
  2. Move the mouse and click the middle button in the top right corner.
  3. If the viewer went fullscreen, click it once more: now it is a window.
EOF
read -rp "Press Enter when the viewer is in windowed mode... " _
