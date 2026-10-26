#!/usr/bin/env bash
# Install the Telegram media viewer fix for niri (per user, no root).
#
#   ./install.sh
#   TG_MEDIA_TITLE_RE='^(Media viewer|Medienbetrachter)$' ./install.sh
#
# NIRI_CONFIG       niri config to patch (default: ~/.config/niri/config.kdl)
# TG_MEDIA_TITLE_RE viewer title regex for your Telegram language
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="${NIRI_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl}"
config_dir="$(dirname "$config")"
title_re="${TG_MEDIA_TITLE_RE:-^(Media viewer|Просмотр медиа)\$}"
bin_dir="$HOME/.local/bin"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
marker='>>> telegram-media-window-niri-fix >>>'

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

for cmd in niri python3 systemctl; do
    command -v "$cmd" >/dev/null || die "$cmd not found"
done
[[ -f "$config" ]] || die "niri config not found: $config (set NIRI_CONFIG)"

backup="$config.bak-telegram-media-$(date +%Y%m%d-%H%M%S)"
cp -- "$config" "$backup"
say "backup: $backup"

install -Dm755 "$here/bin/telegram-media-place" "$bin_dir/telegram-media-place"
install -Dm644 "$here/systemd/telegram-media-place.service" \
    "$unit_dir/telegram-media-place.service"
say "installed $bin_dir/telegram-media-place"

dropin="$unit_dir/telegram-media-place.service.d"
if [[ -n "${TG_MEDIA_TITLE_RE:-}" || "$config_dir" != "${XDG_CONFIG_HOME:-$HOME/.config}/niri" ]]; then
    mkdir -p "$dropin"
    {
        echo "[Service]"
        printf 'Environment="TG_MEDIA_TITLE_RE=%s"\n' "$title_re"
        printf 'Environment="TG_MEDIA_RULE_FILE=%s"\n' "$config_dir/telegram-media.kdl"
    } > "$dropin/override.conf"
fi

# niri refuses to load a config whose include is missing
rule_file="$config_dir/telegram-media.kdl"
[[ -f "$rule_file" ]] || printf '%s\n' \
    '// Written by telegram-media-place: where the Telegram media viewer was closed.' \
    > "$rule_file"

if grep -qF "$marker" "$config"; then
    say "niri config already patched, leaving it as is"
else
    TITLE_RE="$title_re" python3 -I - "$here/niri/telegram-media-viewer.kdl" "$config" <<'EOF'
import os, sys
block = open(sys.argv[1], encoding="utf-8").read()
block = block.replace("__TITLE_RE__", os.environ["TITLE_RE"])
with open(sys.argv[2], "a", encoding="utf-8") as f:
    f.write("\n" + block)
EOF
    say "patched $config"
fi

if ! niri validate -c "$config" >/dev/null 2>&1; then
    cp -- "$backup" "$config"
    niri validate -c "$config" || true
    die "niri rejected the patched config — restored the backup"
fi

systemctl --user daemon-reload
systemctl --user enable --now telegram-media-place.service
systemctl --user restart telegram-media-place.service
say "telegram-media-place is running"

cat <<'EOF'

One last step, once: switch the Telegram media viewer to WINDOWED mode.
  1. Open any photo in Telegram, move the mouse, click the middle
     (maximize/restore) button in the top right corner of the viewer.
  2. If it went fullscreen, click it once more. Telegram remembers this.
Only a close (x) button there? Run ./scripts/show-maximize-button.sh first.
EOF
