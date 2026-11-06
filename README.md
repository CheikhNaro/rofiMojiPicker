# rofimojiPicker

A wide-grid emoji picker built on **Rofi** in Wayland mode: nine category tabs,
fuzzy-ish search with bilingual FR/EN keywords, mouse or keyboard navigation,
Shift+click to accumulate several emojis, and one keystroke from a keybind to
open, select, and paste.

No Gnome/GKB dependency — just Rofi, a data file per category, and a toggle
script that never double-blinks.

## Features

- 🗂 9 category tabs (people, animals, nature, food, activity, travel, objects, symbols, flags) with Nerd Font icons
- 🔎 Search matches English names, French CLDR annotations, and their unaccented variants — filter from any tab and the whole database is searched
- 🖱 Click to select · **Shift+Click** or **right-click** to accumulate · arrow-key grid navigation
- 🔁 Toggle from a single keybind: press again to close, with anti-flicker guards for impatient double-presses
- 📋 Selection lands in the clipboard (`wl-copy`); on **Umbriel** the picker also refocuses your previous window and sends Ctrl+V for you
- 🎨 Theming through one small palette file — matches any Noctalia theme out of the box

## Dependencies

| Package | Needed for | Fedora | Arch |
|---|---|---|---|
| `rofi` ≥ 1.7 (Wayland build) | the picker UI | `sudo dnf install rofi` | `sudo pacman -S rofi` |
| `wl-clipboard` | copying selections (`wl-copy`) | `sudo dnf install wl-clipboard` | `sudo pacman -S wl-clipboard` |
| `jq` | window queries for auto-paste | `sudo dnf install jq` | `sudo pacman -S jq` |
| `wtype` | auto-paste keystroke (Umbriel only) | `sudo dnf install wtype` | `sudo pacman -S wtype` |
| `noto-color-emoji` font | rendering the grid | `sudo dnf install google-noto-color-emoji-fonts` | `sudo pacman -S noto-fonts-emoji` |

Also required: **a Nerd Font** for the category tab icons (the powerline/private
glyphs in the `-modes` line of `rofi-emoji.sh`).
`flock` (util-linux) and `bash` are assumed present.

> `wtype` and `jq` are only used by the Umbriel auto-paste path — skip them if
> you just want clipboard copying.

## Install

```sh
git clone <this-repo-url> rofimojiPicker
cd rofimojiPicker
./install.sh
```

`install.sh` copies `rofi/emoji/` and `rofi/scripts/rofi-emoji.sh` into
`~/.config/rofi/` and only writes `~/.config/rofi/colors.rasi` if you do not
already have one (it never overwrites your palette).

Manual equivalent:

```sh
mkdir -p ~/.config/rofi/scripts
cp -r rofi/emoji ~/.config/rofi/
cp rofi/scripts/rofi-emoji.sh ~/.config/rofi/scripts/
cp -n rofi/colors.rasi ~/.config/rofi/
```

### Bind a key

**Hyprland** (`~/.config/hypr/hyprland.conf`):

```ini
bind = SUPER, PERIOD, exec, bash ~/.config/rofi/scripts/rofi-emoji.sh
```

**Umbriel** (`~/.config/umbriel/modules/keybinds.toml`):

```toml
"Mod+Period" = { action = "spawn bash ~/.config/rofi/scripts/rofi-emoji.sh", repeat = false, cooldown_ms = 500 }
```

**niri** (`~/.config/niri/config.kdl`):

```kdl
binds {
    Mod+Period { spawn "bash" "$HOME/.config/rofi/scripts/rofi-emoji.sh"; }
}
```

Test it first from a terminal: `bash ~/.config/rofi/scripts/rofi-emoji.sh`
(the same command toggles the panel, so running it again closes it).

## Usage

| Action | How |
|---|---|
| Open / close | your keybind (toggle-safe) |
| Pick one emoji and quit | left-click, or `Return` on the highlighted cell |
| Add several without closing | **Shift+left-click** or **right-click** — the banner shows the buffer |
| Switch category | click a tab, or `Tab` / `Shift+Tab` |
| Search | just type; filtered results merge all categories |
| Navigate the grid | arrow keys (or `Ctrl+n` / `Ctrl+p` rows) |
| Cancel | `Esc` — accumulated emojis stay in the clipboard, nothing is auto-pasted |

On final selection the picker copies to the clipboard. Under **Umbriel** it
additionally refocuses the window that was active *before* the panel (skipping
the paste if you closed it) and sends `Ctrl+V` — this works in the terminals
that bind Ctrl+V to paste (foot, kitty, wezterm) and in most GUI apps.

## Moving the panel: anchoring

Positioning is driven by the `window` block of
[`rofi/emoji/emoji.rasi`](rofi/emoji/emoji.rasi) — Rofi re-reads the theme on
every launch, so edits apply on the next keypress, no restart needed:

```css
window {
    width:    820px;      /* panel width */
    location: south;      /* corner the window is placed in */
    anchor:   south;      /* screen point the window is anchored to */
    y-offset: -10px;      /* +x goes right, +y goes down */
}
```

Valid values for both `location` and `anchor`:
`north-west`, `north`, `north-east`, `west`, `center`, `east`,
`south-west`, `south`, `south-east`.

Popular presets — replace the four lines accordingly:

```css
/* centred on screen */
location: center;  anchor: center;  x-offset: 0px;  y-offset: 0px;

/* top centre, like a macOS spotlight */
location: north;   anchor: north;   x-offset: 0px;  y-offset: 20px;

/* bottom-right corner */
location: east;    anchor: south-east;  x-offset: -10px;  y-offset: -10px;

/* left side, vertically centred */
location: west;    anchor: center left; x-offset: 10px;  y-offset: 0px;
```

Keep `location` and `anchor` consistent (same side) so the offsets read
naturally; `x-offset`/`y-offset` are then measured from that edge. On
multi-monitor setups the panel appears on the focused output — there is no
per-output setting in Rofi itself.

Grid density lives in the `listview` block: `columns` and `lines` set the
number of cells, so widen `window.width` with them if the emojis feel cramped.

## Theming

All colors come from `~/.config/rofi/colors.rasi`, imported by `emoji.rasi`:

```css
* {
    bg:      #221f19cc;   /* panel background (alpha allowed) */
    bg-alt:  #2d2a23cc;   /* search bar, tabs, banner */
    fg:      #e9e1d8;     /* text */
    accent:  #e3c370;     /* borders + selection highlight */
    urgent:  #ffb4ab;
}
```

Edit the hex values by hand, or keep it in sync with a theme system: with
Noctalia, add a template entry in `~/.config/noctalia/theme.toml` that
regenerates `colors.rasi` from the active palette (`{{colors.primary...}}`
tokens) on every wallpaper/theme change — the picker is relaunched per keypress,
so it always picks up the newest colors.

## Regenerating the emoji data

`emoji-categories/*.txt` are one line per emoji:
`<emoji>` + tab + search keywords. To rebuild them (needs network access):

```sh
python3 rofi/emoji/rebuild-categories.py
```

The script pulls Unicode CLDR (FR annotations + territory names) and Emojilib
(EN keywords) from GitHub, and the base category list from Noctalia's
`emoji.json`. Not on Noctalia? Point the env var at an equivalent JSON
(`{"<emoji>": {"name": "...", "category": "..."}}`):

```sh
EMOJI_SOURCE_JSON=/path/to/emoji.json python3 rofi/emoji/rebuild-categories.py
```

The shipped files are ready to use — regeneration is optional maintenance.

## Troubleshooting

- **Nothing opens** → run the script in a terminal; if Rofi exits immediately,
  check `rofi -dmenu -version` works on Wayland (`WAYLAND_DISPLAY` set).
- **Empty squares instead of emojis** → install the Noto Color Emoji font (the
  theme requests `"Noto Color Emoji 18/24"`).
- **Tofu on the category tabs** → the tab icons are Nerd Font glyphs; install a
  Nerd Font or replace them with plain words in the `-modes` line of
  `rofi-emoji.sh`.
- **Selecting copies but never pastes** → auto-paste is Umbriel-only today;
  elsewhere paste manually (`Ctrl+V` / middle-click). To enable it on Hyprland,
  replace the three `umbriel` calls in `rofi-emoji.sh` with
  `hyprctl activewindow -j | jq .windowid` (target), a `layers`-equivalent wait
  (or a fixed `sleep 0.6`), and `hyprctl dispatch focuswindow id:<windowid>`.
- **Panel flickers open/closed** → the guards assume ~250 ms for Rofi to map;
  on very slow setups raise `BURST_MS` in `rofi-emoji.sh`.
