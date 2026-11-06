#!/usr/bin/env bash
# ==============================================================================
# rofi-emoji.sh — wide grid emoji picker for Rofi, with category tabs
# ==============================================================================
#
# Anti-flicker. The panel takes ~220 ms to map; a keypress within the first
# second is an impatient double-press, not a close request. Swallowing it
# keeps the panel open and removes the close/reopen cycle that used to look
# like two blinks. Past BURST_MS the toggle behaves normally again: an open
# surface is closed on the next press.
#
# The script only ever kills the rofi it launched (pid verified), never
# somebody else's: a launcher rofi running in parallel is ignored, not killed.
#
# A flock around the decision serializes near-simultaneous presses: the second
# invocation sees the first instance's state and stays quiet.

set -u
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/rofi-emoji"
PID_FILE="$STATE_DIR/pid"
T0_FILE="$STATE_DIR/started"
CLOSED_FILE="$STATE_DIR/closed"
LOCK_FILE="$STATE_DIR/lock"

START_GUARD_MS=400     # surface not mapped yet: closing would make no sense
BURST_MS=2500          # impatient burst window: the press is swallowed
CLOSE_GUARD_MS=300     # rofi takes a moment to disappear after a kill

now_ms() { echo $(( $(date +%s%N) / 1000000 )); }

own_alive() {
    local p
    p=$(cat "$PID_FILE" 2>/dev/null)
    [[ -n "$p" ]] && kill -0 "$p" 2>/dev/null \
        && [[ "$(cat "/proc/$p/comm" 2>/dev/null)" == rofi ]]
}

age_ms() {
    local t0
    t0=$(cat "$T0_FILE" 2>/dev/null)
    [[ -n "$t0" ]] || return 1
    echo $(( $(now_ms) - t0 ))
}

mkdir -p "$STATE_DIR"
exec 8>"$LOCK_FILE"
flock -w 1 8 || exit 0

if own_alive; then
    age=$(age_ms) || age=0
    (( age < START_GUARD_MS )) && exit 0
    (( age < BURST_MS )) && exit 0
    p=$(cat "$PID_FILE" 2>/dev/null)
    kill "$p" 2>/dev/null
    now_ms > "$CLOSED_FILE"
    exec 8>&-
    exit 0
fi

# Closed a moment ago: the user pressed while rofi was still fading out
if [[ -f "$CLOSED_FILE" ]] && (( $(now_ms) - $(cat "$CLOSED_FILE" 2>/dev/null || echo 0) < CLOSE_GUARD_MS )); then
    exit 0
fi

# A rofi that is not ours holds rofi's lock: do not kill it, do not fail
# loudly — ignore the press.
pgrep -x rofi >/dev/null 2>&1 && exit 0

# Clean up a possibly orphaned rofi pidfile
ROFI_PID_FILE="${XDG_RUNTIME_DIR:-/run/user/$UID}/rofi.pid"
if [[ -f "$ROFI_PID_FILE" ]]; then
    OLD=$(cat "$ROFI_PID_FILE" 2>/dev/null)
    if [[ -n "$OLD" ]] && ! kill -0 "$OLD" 2>/dev/null; then
        rm -f "$ROFI_PID_FILE"
    fi
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMOJI_DIR="$DIR/../emoji"
SCRIPT="$EMOJI_DIR/emoji-category.sh"
THEME="$EMOJI_DIR/emoji.rasi"
SEL_FILE="${XDG_RUNTIME_DIR:-/tmp}/rofi-emoji-selected"
SEL_FINAL="$SEL_FILE.final"

rm -f "$SEL_FILE" "$SEL_FINAL"
now_ms > "$T0_FILE"

# Active window before rofi: this is the auto-paste target. Refocusing it
# explicitly avoids relying on the compositor's focus restoration (the user
# may switch windows while selecting). Requires the `umbriel` CLI; elsewhere
# PREV_ID stays empty and the picker only copies to the clipboard.
PREV_ID=$(umbriel windows --json 2>/dev/null | jq -r '[.[] | select(.active == true)][0].id // empty')

# Launch rofi
rofi \
    -modes ":${SCRIPT} people,󰏩:${SCRIPT} animals,󰾢:${SCRIPT} nature,󰶟:${SCRIPT} food,󰒸:${SCRIPT} activity,󰄋:${SCRIPT} travel,󰌵:${SCRIPT} objects,:${SCRIPT} symbols,:${SCRIPT} flags" \
    -show "" \
    -theme "$THEME" \
    -p "" \
    -normal-window </dev/null >/dev/null 2>&1 8>&- &
RPID=$!
echo "$RPID" > "$PID_FILE"

exec 8>&-

rc=0
wait "$RPID" || rc=$?

rm -f "$PID_FILE" "$T0_FILE"
now_ms > "$CLOSED_FILE"

if [[ -f "$SEL_FILE" ]]; then
    CHOSEN=$(cat "$SEL_FILE")
    rm -f "$SEL_FILE"
    if [[ -n "$CHOSEN" ]]; then
        printf "%s" "$CHOSEN" | wl-copy
        # Auto-paste only after a real final selection (.final marker):
        # an Esc after shift-accumulation keeps the clipboard without pasting.
        # foot, kitty and wezterm all bind Ctrl+V to paste.
        if [[ -f "$SEL_FINAL" && -n "${PREV_ID:-}" ]]; then
            # Rofi's close is animated (220 ms) and its surface keeps keyboard
            # focus during the fade: a Ctrl+V too early lands nowhere. Wait for
            # the rofi layer to be unmapped.
            for _ in $(seq 1 30); do
                umbriel layers --json 2>/dev/null \
                    | jq -e 'any(.[]; .namespace == "rofi" and .mapped == true)' >/dev/null \
                    || break
                sleep 0.05
            done
            # Keyboard focus restoration follows the layer fade (220 ms):
            # without this margin the Ctrl+V fires before the target window
            # receives the keyboard.
            sleep 0.35
            # The target may have been closed while selecting: never paste
            # blindly into whatever window took its place.
            if umbriel windows --json 2>/dev/null \
                | jq -e --arg w "$PREV_ID" 'any(.[]; .id == $w)' >/dev/null; then
                umbriel msg window-focus "$PREV_ID" 2>/dev/null
                sleep 0.1
                wtype -M ctrl -k v -m ctrl >/dev/null 2>&1
            fi
        fi
    fi
fi
rm -f "$SEL_FINAL"
