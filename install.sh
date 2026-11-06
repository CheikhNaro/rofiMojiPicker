#!/usr/bin/env bash
# Install rofimojiPicker into the user Rofi config directory.
set -eu

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"

mkdir -p "$DEST/scripts"
cp -r "$SRC/rofi/emoji" "$DEST/"
cp "$SRC/rofi/scripts/rofi-emoji.sh" "$DEST/scripts/"
chmod +x "$DEST/scripts/rofi-emoji.sh" "$DEST/emoji/emoji-category.sh"

# Never clobber an existing palette (e.g. one driven by Noctalia templates).
if [[ -e "$DEST/colors.rasi" ]]; then
    echo "keeping existing $DEST/colors.rasi (bundled default: $SRC/rofi/colors.rasi)"
else
    cp "$SRC/rofi/colors.rasi" "$DEST/"
fi

echo "Installed. Bind a key to: bash $DEST/scripts/rofi-emoji.sh"
