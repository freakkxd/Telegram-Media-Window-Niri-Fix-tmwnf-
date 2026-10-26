#!/usr/bin/env bash
# Remove the Telegram media viewer fix for niri.
set -euo pipefail

config="${NIRI_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl}"
config_dir="$(dirname "$config")"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

systemctl --user disable --now telegram-media-place.service 2>/dev/null || true
rm -f "$HOME/.local/bin/telegram-media-place" \
    "$unit_dir/telegram-media-place.service"
rm -rf "$unit_dir/telegram-media-place.service.d"
systemctl --user daemon-reload
say "removed the telegram-media-place service"

if [[ -f "$config" ]] && grep -qF '>>> telegram-media-window-niri-fix >>>' "$config"; then
    cp -- "$config" "$config.bak-telegram-media-uninstall-$(date +%Y%m%d-%H%M%S)"
    python3 -I - "$config" <<'EOF'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
text = re.sub(r"\n*// >>> telegram-media-window-niri-fix >>>.*?"
              r"// <<< telegram-media-window-niri-fix <<<\n?", "\n", text, flags=re.S)
open(path, "w", encoding="utf-8").write(text.rstrip("\n") + "\n")
EOF
    say "removed the block from $config"
fi
rm -f "$config_dir/telegram-media.kdl"
say "done"
