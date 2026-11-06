#!/usr/bin/env bash
# ==============================================================================
# rofi-emoji.sh — Sélecteur d'émojis Rofi en grille large avec catégories
# ==============================================================================
#
# Anti-clignotement. Le panneau met ~220 ms à apparaître ; un appui dans la
# seconde qui suit est un appui d'impatience, pas une demande de fermeture.
# Avaler cet appui laisse le panneau ouvert et supprime le va-et-vient
# fermeture/réouverture qui se voyait comme deux clignotements. Au-delà de
# BURST_MS, la bascule redevient normale : surface ouverte → fermeture.
#
# Le script ne tue que le rofi qu'il a lancé (pid vérifié), jamais un autre :
# un lanceur rofi ouvert en parallèle est ignoré au lieu d'être tué.
#
# Verrou flock autour de la décision : deux appuis quasi simultanés sont
# sérialisés, le second voit l'instance du premier et se tait.

set -u
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/rofi-emoji"
PID_FILE="$STATE_DIR/pid"
T0_FILE="$STATE_DIR/started"
CLOSED_FILE="$STATE_DIR/closed"
LOCK_FILE="$STATE_DIR/lock"

START_GUARD_MS=400     # surface pas encore mappée : fermer n'aurait aucun sens
BURST_MS=2500          # rafale d'impatience : l'appui est avalé
CLOSE_GUARD_MS=300     # rofi met un instant à disparaître après un kill

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

# Fermeture à l'instant : l'utilisateur a appuyé pendant que rofi s'en allait
if [[ -f "$CLOSED_FILE" ]] && (( $(now_ms) - $(cat "$CLOSED_FILE" 2>/dev/null || echo 0) < CLOSE_GUARD_MS )); then
    exit 0
fi

# Un rofi qui n'est pas le nôtre tient le verrou de rofi : ne pas le tuer, ne pas
# échouer bruyamment, ignorer l'appui.
pgrep -x rofi >/dev/null 2>&1 && exit 0

# Nettoyage d'un éventuel pidfile rofi orphelin
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

# Fenêtre active avant rofi : c'est la cible du collage automatique. La
# refocaliser explicitement évite de dépendre de la restauration de focus du
# compositeur (l'utilisateur peut changer de fenêtre pendant la sélection).
PREV_ID=$(umbriel windows --json 2>/dev/null | jq -r '[.[] | select(.active == true)][0].id // empty')

# Lancer rofi
rofi \
    -modes ":${SCRIPT} people,󰏩:${SCRIPT} animals,󰾢:${SCRIPT} nature,󰶟:${SCRIPT} food,󰒸:${SCRIPT} activity,󰄋:${SCRIPT} travel,󰌵:${SCRIPT} objects,:${SCRIPT} symbols,:${SCRIPT} flags" \
    -show "" \
    -theme "$THEME" \
    -p "" \
    </dev/null >/dev/null 2>&1 8>&- &
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
        # Collage auto seulement après une vraie sélection (marqueur .final) :
        # un Esc après accumulation Shift garde le presse-papier sans coller.
        # foot, kitty et wezterm ont tous Ctrl+V → coller.
        if [[ -f "$SEL_FINAL" && -n "${PREV_ID:-}" ]]; then
            # La fermeture de rofi est animée (220 ms) et sa surface garde le
            # focus clavier pendant le fondu : un Ctrl+V trop tôt part dans le
            # vide. On attend que le calque rofi soit démonté.
            for _ in $(seq 1 30); do
                umbriel layers --json 2>/dev/null \
                    | jq -e 'any(.[]; .namespace == "rofi" and .mapped == true)' >/dev/null \
                    || break
                sleep 0.05
            done
            # La restauration du focus clavier suit le fondu du calque
            # (220 ms) : sans cette marge, le Ctrl+V part avant que la
            # fenêtre cible ne reçoive le clavier.
            sleep 0.35
            # La cible a pu être fermée pendant la sélection : ne pas coller
            # à l'aveugle dans une autre fenêtre.
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
