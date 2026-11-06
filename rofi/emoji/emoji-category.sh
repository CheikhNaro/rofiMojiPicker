#!/usr/bin/env bash
# ==============================================================================
# emoji-category.sh — Rofi mode script for one emoji category
# Handles simple selection (paste and quit) and multiple (Shift to accumulate)
# ==============================================================================

CATEGORY="$1"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAT_FILE="$DIR/emoji-categories/${CATEGORY}.txt"
SEL_FILE="${XDG_RUNTIME_DIR:-/tmp}/rofi-emoji-selected"

if [[ "$ROFI_RETV" -eq 1 ]]; then
    # Normal final selection (no Shift): store it, mark for auto-paste,
    # and leave rofi immediately
    SELECTED="$2"
    if [[ -n "$SELECTED" ]]; then
        printf "%s" "$SELECTED" >> "$SEL_FILE"
        : > "$SEL_FILE.final"
    fi
    exit 0
elif [[ "$ROFI_RETV" -eq 2 || "$ROFI_RETV" -ge 10 ]]; then
    # Shift selection: append the emoji to the buffer without closing
    SELECTED="$2"
    if [[ -n "$SELECTED" ]]; then
        printf "%s" "$SELECTED" >> "$SEL_FILE"
        wl-copy < "$SEL_FILE" 2>/dev/null
    fi
fi

# Enable custom hot-keys and keep position and filter
echo -en "\0use-hot-keys\x1ftrue\n"
echo -en "\0keep-selection\x1ftrue\n"
echo -en "\0keep-filter\x1ftrue\n"

# If emojis were already accumulated (via Shift), show the info banner
if [[ -f "$SEL_FILE" && -s "$SEL_FILE" ]]; then
    ACC=$(cat "$SEL_FILE")
    echo -en "\0message\x1fSelected: ${ACC}   (Shift+Click to add more • Click without Shift to paste)\n"
fi

# List the emojis of the category
if [[ -f "$CAT_FILE" ]]; then
    cat "$CAT_FILE"
else
    echo "❌ Category not found: $CATEGORY"
fi
