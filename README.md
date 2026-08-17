# dotfiles

A Hyprland desktop built as a design system. One JSON file defines every colour,
size, duration and easing curve; a generator expands it into **84 files** across
14 targets — the shell, compositor, terminal, login screen, file manager, editor,
Spotify client, audio visualiser, and a documentation site.

The visual language is the **PS3 XMB**: cold silver-blue, one glowing accent,
chrome surfaces, thin geometric type, and motion in a wave field behind the
interface.

Felt like using AI for this one because my previous rice took genuinely 10x as long without AI. 
I had an idea of what I wanted and  did not feel like going through each change one by one myself tbh.


MIT licensed. Live at
**[gelogonza.github.io/dotfiles](https://gelogonza.github.io/dotfiles/)**.

---

## Contents

| | |
|---|---|
| [How it works](#how-it-works) | the token pipeline and its two gates |
| [Structure](#structure) | what is in the tree |
| [Requirements](#requirements) | packages, and what each is for |
| [Setup](#setup) | clone → link → fonts → cursor → log in |
| [Usage](#usage) | keybinds, surfaces, scripts, IPC |
| [Design system](#design-system) | palette, type, space, motion, material |
| [What is themed](#what-is-themed) | every generated output |
| [Changing things](#changing-things) | edit tokens, regenerate, restart |
| [Reference](#reference) | the other documents |
| [Troubleshooting](#troubleshooting) | symptom → cause → fix |
| [Known gaps](#known-gaps) | what is deliberately unfinished |

---

## How it works

`design/tokens.json` is the only file anyone edits by hand.
`design/build-tokens.py` reads it and writes every consumer. Generated files
carry a `GENERATED FILE — DO NOT EDIT` banner and are committed, so a fresh clone
works without running anything.

```
design/tokens.json ──► design/build-tokens.py ──► 84 files, 14 targets
```

Shared QML components, GLSL shaders and SVG icons live once in `design/` and are
copied into each QML import root, with the `Theme` import rewritten per
destination. QML has no cross-root import path, which is why they are copied
rather than referenced.

Two gates:

```bash
design/build-tokens.py --check    # fails if any generated file is stale
design/build-tokens.py --audit    # measures 44 text/surface pairs against WCAG
```

`--audit` is not decoration. When the palette was inverted, `text-2` silently
dropped below AA on all three light surfaces, and nothing else would have caught
it.

---

## Structure

```
design/            tokens.json, the generator, shared QML/GLSL/SVG   ← edit here
quickshell/gelo/   the shell
  Bar/             three top plates: workspaces+media, clock, status
  Dock/            auto-hiding bottom dock
  MiniPlayer/      transport panel
  Dashboard/       calendar, agenda, weather, system load
  Launcher/        command palette: apps, clipboard, notifications, windows
  Notifications/   notification daemon and history
  PowerMenu/       lock, sleep, log out, reboot, shut down
  Lock/            ext-session-lock client
  Wallpaper/       the wave-field shader
  Services/        singletons: media, audio, bluetooth, agenda, windows, …
  scripts/         agenda.py, weather.sh
hypr/              compositor config; scripts/ for lock, screenshot, colour
                   picker, cava launcher
sddm/              login theme + installer
ghostty/           terminal
gtk-3.0/ gtk-4.0/  GTK + libadwaita palette overrides (dark)
vscode/            generated theme extension
spicetify/         generated Spotify theme
cava/              audio visualiser
fastfetch/         fetch tool
docs/              procedures, and the generated GitHub Pages site

waybar/ wofi/ mako/   superseded; kept so the rollback column below is real
vlc/ git/ systemd/    incidental ~/.config residents; nothing reads them
```

---

## Requirements

Arch. Everything is in the official repos except Geist.

```bash
sudo pacman -S --needed \
  hyprland xdg-desktop-portal-hyprland \
  quickshell qt6-shadertools qt6-wayland qt6-5compat qt6-declarative \
  hyprlock hypridle hyprpolkitagent ghostty fastfetch nautilus \
  grim slurp cliphist wl-clipboard brightnessctl playerctl jq \
  pipewire pipewire-pulse wireplumber pavucontrol \
  python python-dateutil imagemagick \
  adwaita-cursors inter-font noto-fonts-emoji
```

Verified against **Hyprland 0.56** and **Quickshell 0.3.0**. The shell uses
`Quickshell.Hyprland`, `WlrLayershell` and `ext-session-lock`, all of which have
moved between releases. `quickshell` is AUR-only on some setups
(`quickshell-git`).

| Package | Needed for |
|---|---|
| `python-dateutil` | recurring calendar events. Without it a weekly class appears **once** and never again, silently |
| `imagemagick` | colour swatch in the picker notification, dimensions in the screenshot notification |
| `nautilus`, `pavucontrol` | what `SUPER+E` and a click on the volume control open |
| `xdg-desktop-portal-hyprland` | screen sharing, file pickers. Not pulled in automatically |
| `jq`, `playerctl` | cava's sink resolution, media keys |

Optional. Each feature hides itself rather than erroring:

| Package | Enables |
|---|---|
| `cava` | audio visualiser |
| `hyprpicker` | `SUPER+SHIFT+C` colour picker |
| `swappy` | Annotate button on the screenshot notification |
| `bluez bluez-utils blueman` | Bluetooth control in the bar |
| `nvidia-utils` | GPU line in the dashboard |
| `spicetify-cli` | Spotify theme |
| `sddm` | login theme — opt-in, see [docs/login-screen.md](docs/login-screen.md) |

---

## Setup

The repo *is* `~/.config`. Ten entries are symlinked into it, replacing whatever
is at those paths.

**1. Back up.** `ln -sfn` overwrites without asking.

```bash
cp -a ~/.config ~/.config.bak-$(date +%F)
```

**2. Clone and link.**

```bash
git clone https://github.com/gelogonza/dotfiles ~/Coding/dotfiles-gelo
ln -s ~/Coding/dotfiles-gelo ~/dotfiles

for d in hypr quickshell ghostty fastfetch gtk-3.0 gtk-4.0 cava; do
  ln -sfn ~/dotfiles/$d ~/.config/$d
done

# Superseded, but makes the rollback column below work. Skip freely.
for d in waybar wofi mako; do ln -sfn ~/dotfiles/$d ~/.config/$d; done
```

Every `~/.config` link points at `~/dotfiles`, so moving the repo means
repointing one symlink. Check them with `find ~/.config -maxdepth 1 -xtype l` —
silence is correct.

**3. Replace four machine-specific values.** Three of these break a first login.

| Where | What | Fix |
|---|---|---|
| `hypr/hyprland.conf` ~line 14 | `monitor=DP-1`, `monitor=HDMI-A-1` | `hyprctl monitors`, then edit. `monitor=,preferred,auto,1` works anywhere |
| `hypr/hyprland.conf` ~line 84 | four `env = …nvidia…` lines | comment out on AMD/Intel |
| `systemd/user/reset-monitors.service` | calls a script not in this repo | don't link `systemd/`, or delete the unit |
| `hypr/hyprland.conf` `exec-once` | starts `firefox`, `nm-applet`, `gnome-keyring-daemon` | comment out what you don't want |

**4. Fonts.** Geist is not packaged for Arch.

```bash
mkdir -p ~/.local/share/fonts
curl -fsSL -o ~/.local/share/fonts/Geist.ttf \
  "https://github.com/google/fonts/raw/main/ofl/geist/Geist%5Bwght%5D.ttf"
fc-cache -f ~/.local/share/fonts
```

**5. Cursor theme.** Not committed — ~12MB derived from Adwaita.

```bash
design/build-cursor.py
```

**6. Log out and back in.** `env` variables in `hyprland.conf` (`XCURSOR_THEME`)
only apply to newly started processes.

**7. Verify.** Five checks, in the order things fail.

```bash
find ~/.config -maxdepth 1 -xtype l   # nothing = every link resolves
hyprctl configerrors                  # empty = compositor happy
pgrep -x quickshell                   # a PID = shell up
fc-list | grep -ci geist              # ≥1 = no tofu
design/build-tokens.py --check        # exits 0 = outputs match tokens
```

### Optional extras

**VS Code** — symlink so regenerating updates it in place:

```bash
ln -sfn ~/dotfiles/vscode/gelo-xmb ~/.vscode/extensions/gelo-xmb
```

Then set **both** keys in `settings.json` and reload:

```json
"workbench.colorTheme": "gelo XMB",
"workbench.preferredHighContrastColorTheme": "gelo XMB"
```

Both, not one. Electron reports high contrast on this setup, and when it does VS
Code ignores `workbench.colorTheme` entirely. Setting only the obvious key is a
silent no-op.

**Spotify** — spicetify *modifies the Spotify install*. Read
**[docs/spotify.md](docs/spotify.md)** first; it covers restore and the one
command that destroys your way back to stock.

```bash
ln -sfn ~/dotfiles/spicetify/gelo-xmb ~/.config/spicetify/Themes/gelo-xmb
spicetify config current_theme gelo-xmb color_scheme base
spicetify apply
```

**cava** — alias it, or it reads the wrong sink:

```bash
echo "alias cava='~/dotfiles/hypr/scripts/cava-launch.sh'" >> ~/.zshrc
```

**Calendar** — put secret ICS addresses in `~/.config/gelo/calendars.json`
(Google: Settings → calendar → "Secret address in iCal format"; Outlook:
Settings → Calendar → Shared calendars → Publish):

```bash
mkdir -p ~/.config/gelo && chmod 700 ~/.config/gelo
$EDITOR ~/.config/gelo/calendars.json   # [{ "name": "personal", "url": "…" }]
chmod 600 ~/.config/gelo/calendars.json
```

That file is deliberately outside the repo. The repo is `~/.config` and is pushed
to GitHub; those URLs are bearer secrets. Nothing in the shell prints one, even on
failure — a bad feed reports `name: ExceptionType`.

**Weather** — off by default; it queries a third-party server every 15 minutes
and, with no location set, that server geolocates you by IP. Set
`weather.enabled` and `weather.location` in `tokens.json`, then regenerate.

**Login screen** — separate, opt-in, and it means switching display managers.
Read **[docs/login-screen.md](docs/login-screen.md)** first; it has the TTY
recovery procedure.

---

## Usage

### Surfaces

| Surface | Opens with | Contents |
|---|---|---|
| **Bar** | always | three plates: workspaces + now playing · clock + date · weather, tray, volume, Bluetooth, keep-awake, power |
| **Dock** | hover the bottom edge | nine pinned apps, magnifying on hover, running indicators |
| **Mini player** | click the now-playing title | art, title/artist/album, seekable progress, prev · play · next · shuffle |
| **Launcher** | `SUPER+R` | apps, clipboard, notification history, window switcher — one palette, four modes |
| **Dashboard** | click the clock | month calendar, agenda, weather, CPU/MEM/GPU |
| **Power menu** | power icon | lock, sleep, log out, reboot, shut down |
| **Lock** | `SUPER+L` | wave-field shader over a PAM prompt |

The bar is one layer surface with three plates drawn inside it, because Hyprland
only honours an exclusive zone from a surface that spans its edge. Its input
region is masked to the plates, so the gaps are click-through. The dock is masked
the same way — 6px of live screen while hidden.

### Keybinds

| Key | Action |
|---|---|
| `SUPER+R` / `SUPER+D` | command palette |
| `SUPER+Q` / `SUPER+Return` | terminal |
| `SUPER+C` | close window |
| `SUPER+E` | file manager |
| `SUPER+V` | float window |
| `SUPER+L` | lock (shader lock, falls back to hyprlock) |
| `SUPER+SHIFT+L` | lock (hyprlock — standalone, no shell dependency) |
| `SUPER+SHIFT+V` | clipboard history |
| `SUPER+SHIFT+N` | notification history |
| `SUPER+SHIFT+D` | dashboard |
| `SUPER+SHIFT+I` | keep screen awake (toggle) |
| `SUPER+Tab` / `ALT+Tab` | window switcher |
| `SUPER+S` / `Print` | screenshot region |
| `SUPER+SHIFT+S` | screenshot everything |
| `SUPER+ALT+S` | screenshot window (snaps to edges) |
| `SUPER+SHIFT+C` | pick colour — hex to clipboard, names nearest token |
| `SUPER+1..0` | switch workspace |
| `SUPER+SHIFT+1..0` | move window to workspace |
| `` SUPER+` `` / `` SUPER+SHIFT+` `` | scratchpad — toggle / send to |
| `SUPER+arrows` | move focus |
| `SUPER+drag` / `SUPER+right-drag` | move / resize window |
| media & volume keys | `playerctl` / `wpctl` / `brightnessctl` |

`SUPER+SHIFT+V` rather than `SUPER+V` because Hyprland fires **every** binding
matching a chord rather than picking one, and `SUPER+V` is `togglefloating`. The
scratchpad is on `` ` `` for the same reason — stock puts it on `S`, where the
screenshot binds are. Check for collisions with `hyprctl binds`: two entries
sharing a `modmask` and `key` is always a conflict, never a precedence.

### Scripts

| Script | Does |
|---|---|
| `hypr/scripts/lock.sh` | the one entry point for locking. Prefers the shader lock, falls back to hyprlock if the shell is unreachable |
| `hypr/scripts/screenshot.sh` | `region` / `window` / `full` — clipboard **and** `~/Pictures/Screenshots` |
| `hypr/scripts/pick-colour.py` | hex to clipboard, plus the nearest design token by CIEDE2000 |
| `hypr/scripts/cava-launch.sh` | resolves the sink that is actually playing, then starts cava |
| `quickshell/gelo/scripts/agenda.py` | fetches ICS feeds, expands RRULE. Never prints a URL |

### IPC

```bash
qs -c gelo ipc call launcher toggle       # or open / close / search <q>
qs -c gelo ipc call launcher clipboard    # or notifications / windows
qs -c gelo ipc call dashboard toggle      # or open / close
qs -c gelo ipc call player toggle         # or open / close
qs -c gelo ipc call dock toggle           # or open / close / status
qs -c gelo ipc call power toggle          # or open / close
qs -c gelo ipc call idle toggle           # or on / off / status
qs -c gelo ipc call lock lock             # or preview
```

`open`/`close`, not `show`/`hide`: `quickshell ipc show` is the CLI's own
subcommand, so `ipc call <target> show` prints the target listing and **exits 0**
without reaching the handler.

**Idle**: locks at 5 minutes, displays off at 10 (`hypr/hypridle.conf`), through
`lock.sh`.

---

## Design system

Full rationale in **[design.md](design.md)**. The short version:

**Colour.** Cold silver-blue, zero warm hues. Light chrome, dark content.

| Group | Role |
|---|---|
| `color` | the light surfaces the shell chrome is made of, plus ink and accent |
| `dark` | the dark ramp GTK apps use, anchored on `terminal.background` |
| `terminal` | Ghostty: dark background, 16 ANSI slots |

**The accent appears in exactly three places, system-wide:** the active workspace
indicator, the focused window border, and the cursor. Nowhere else. Selection,
hover, urgency, volume level and progress are carried by elevation, ink colour and
opacity instead. Two sanctioned exceptions: the ripple wavefront (sub-second,
transient) and terminal ANSI 1/3/9/11 (genuinely red and yellow because tools
depend on them).

**Type.** One geometric sans — Geist — at 300 with 400 for emphasis. Never 500+:
weight is not how this system creates hierarchy. Three sizes: caption 11, body 13,
title 15. Tabular figures in the clock so numerals do not jitter.

**Space & radius.** 4px grid: 4 · 8 · 12 · 16 · 24 · 32. Radius 8 · 12 · 16 · 24
· 999.

**Motion.** Three durations — 150 · 250 · 400 — and one bezier. Motion lives in
the wave field *behind* the interface; elements do not slide. One sanctioned
exception: the now-playing marquee, because a track title is the only label here
routinely longer than its space.

**Material.** `Chrome` is brushed metal — a 96%-opaque vertical gradient, a
hairline, a soft shadow. Deliberately **not** frosted glass; there is no backdrop
blur anywhere, and enabling it washes out the hairline and glow that carry the
material. Selection is a **glow**, not an outline or a fill. `Reflection` puts a
faded mirror under icons. Nine component blocks live under `material`: `chrome`,
`glow`, `reflection`, `blob`, `bar`, `marquee`, `miniPlayer`, `dock`, `ripple`.

**The wave field** is one GLSL shader authored once in `design/shaders/`, compiled
to `.qsb` for Qt and retargeted to WebGL2 for the site, so the documentation
cannot drift from the desktop.

---

## What is themed

Every file below is generated from `design/tokens.json`. Editing any of them
directly is one regenerate away from being erased.

| Target | Output | Consumes |
|---|---|---|
| Quickshell shell | `quickshell/gelo/Theme/Tokens.qml` | everything |
| SDDM greeter | `sddm/themes/gelo-liquid/Theme/Tokens.qml` | separate QML import root |
| Hyprland | `hypr/tokens.conf` | borders, gaps, rounding, animation curves |
| Ghostty | `ghostty/gelo-theme` | background, foreground, cursor, 16 ANSI |
| GTK 4 / libadwaita | `gtk-4.0/gtk.css` | 37 named colours — **dark** |
| GTK 3 | `gtk-3.0/gtk.css` | 12 names — GTK3 reads a smaller set — **dark** |
| VS Code | `vscode/gelo-xmb/` — theme + manifest | 277 colours, 21 token scopes |
| Spotify | `spicetify/gelo-xmb/` — `color.ini`, `user.css`, `theme.js` | Encore colour sets, chrome, the XMB shader behind the app |
| cava | `cava/config` | gradient stops |
| CSS tier | `design/tokens.css` | custom properties for GTK and the site |
| Figma / TS bridge | `design/tokens.dtcg.json`, `design/tokens.ts` | W3C DTCG format, typed TS |
| Docs site | `docs/*.html` | four pages, styled by the tokens they document |
| Shared QML | `Components/` in both QML roots | `Chrome`, `Glow`, `Icon`, `Reflection` |
| Shaders & icons | `Shaders/`, `icons/` in both roots | GLSL `.qsb`, 26 SVGs |

Not generated, but part of the theme:

| | |
|---|---|
| `design/build-cursor.py` | recolours a base XCursor theme to the accent. Output not committed |
| `sddm/themes/gelo-liquid/` | greeter QML + the one real GLSL background in the system |
| `hypr/gelo.conf` | the compositor-side half: no layer blur, window blur for the translucent terminal, focus border |
| `hypr/hyprlock.conf` | fallback lock, same tokens |
| `fastfetch/config.jsonc` | palette written by hand — fastfetch has no include mechanism |

**Every compositor-side change is in `hypr/gelo.conf`**, sourced by one line at
the bottom of `hyprland.conf`. Delete that line to revert all of them.

### What this replaces

| Was | Now | Roll back by |
|---|---|---|
| Waybar | Quickshell bar | comment `exec-once = quickshell -c gelo`, add `exec-once = waybar` |
| wofi / hyprlauncher | Quickshell launcher | point `$menu` at `wofi --show drun` |
| mako | Quickshell notifications | uncomment `exec-once = mako`, stop the shell |
| hyprpaper | shader wallpaper | uncomment `exec-once = hyprpaper` |
| GDM | SDDM (opt-in, not enabled) | [docs/login-screen.md](docs/login-screen.md) |
| Halcyon (VS Code) | generated `gelo XMB` | `workbench.colorTheme` + the high-contrast key |
| StarryNight (Spotify) | generated `gelo-xmb` | [docs/spotify.md](docs/spotify.md) |

---

## Changing things

```bash
$EDITOR design/tokens.json
design/build-tokens.py
design/build-shaders.sh          # if you touched colours the shader reads
design/build-cursor.py           # if you touched the accent
sudo sddm/install.sh             # if the login theme is installed
pkill -x quickshell; setsid quickshell -c gelo >/dev/null 2>&1 &
```

Then `--check` and `--audit` before committing.

Common edits:

| Want | Change |
|---|---|
| Clock format, units | `format.clock` (`12h`/`24h`), `format.units` (`imperial`/`metric`) |
| Font | `type.display`. Figtree, Inter Display and Nimbus Sans are installed |
| Dock apps | `apps` in `Dock/Dock.qml` — `icon`, `exec`, `match`. Get classes from `hyprctl clients -j \| jq -r '.[].class'` |
| Hide a tray icon | `ignore` in `Bar/TrayRow.qml`, substring of `id` + `title` |
| Which players count as music | `ignore` in `Services/Media.qml`. Browsers are filtered out — they report the *page title* as the track |
| GTK back to light | set the `dark` block to the light values |

**Don't** edit anything with a `GENERATED FILE` banner; don't edit
`quickshell/gelo/Components/`, `*/Shaders/` or `*/icons/` (copies — originals in
`design/`); don't move the repo without repointing `~/dotfiles`; don't add a
fourth accent location; don't run mako alongside the shell
(`org.freedesktop.Notifications` is single-owner); don't enable blur on the shell
layer surfaces.

Keep a rescue TTY free (`Ctrl+Alt+F3`) the first time you touch the lock screen or
display manager. Check which VT you are on with
`loginctl show-session $XDG_SESSION_ID -p VTNr` and pick another.

---

## Reference

| Document | What it is |
|---|---|
| **[design.md](design.md)** | the design system in full — pipeline, type, colour, materials, shaders, ripple bus, cursor, GTK, editor, Spotify, invariants |
| **[docs/CHANGES.md](docs/CHANGES.md)** | every change with its reasoning, and the failures. The longest document here and the most useful |
| **[docs/handoff.md](docs/handoff.md)** | picking this up cold — current state, environment traps, what breaks |
| **[docs/roadmap.md](docs/roadmap.md)** | what is next |
| **[docs/lock-screen.md](docs/lock-screen.md)** | the shader lock, PAM, and how to test it without locking yourself out |
| **[docs/login-screen.md](docs/login-screen.md)** | SDDM install, and the TTY recovery procedure. Read before switching display managers |
| **[docs/spotify.md](docs/spotify.md)** | spicetify, restore, and the one command that destroys your way back to stock |
| **[the site](https://gelogonza.github.io/dotfiles/)** | generated from `docs/*.html`: the system, the wave field, the accessibility audit, the token bridge |

Third-party material: the cursor is recoloured from **Adwaita** (CC-BY-SA 3.0) and
is not committed; `design/build-cursor.py` reproduces it. **Geist** (Vercel, OFL)
is fetched at install time. Early keybind and Quickshell-API reference came from
**43PR/dotfiles**; none of it remains.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Desktop unstyled | `~/dotfiles` doesn't resolve | `ln -s <repo> ~/dotfiles`, then `find ~/.config -maxdepth 1 -xtype l` |
| Bar missing | shell not running, or a QML error | run `quickshell -c gelo` and read stderr |
| Wrong resolution, black second screen | the `monitor=` lines are mine | `hyprctl monitors`, edit `hyprland.conf` |
| Session won't start on AMD/Intel | the NVIDIA `env` block | comment out those four lines |
| Windows sit under the bar | exclusive zone not applied | `hyprctl monitors` → `reserved` should be `[0,56,0,0]` |
| Boxes instead of glyphs | Geist missing | install fonts, `fc-cache -f` |
| Wallpaper is a flat colour | shader not baked | `design/build-shaders.sh` |
| Old cursor | env vars only apply to new processes | log out and back in |
| Recurring event shows once | `python-dateutil` missing | `sudo pacman -S python-dateutil` |
| Calendar says "add calendars.json" | no feeds configured | working as intended — see Setup |
| Calendar says "Could not read …" | bad or expired ICS URL | a `ValueError` usually means the placeholder is still there |
| Dock indicator missing for an app | class ≠ icon name | `hyprctl clients -j \| jq -r '.[].class'`, fix `match` |
| Now playing shows a browser tab | browser MPRIS session | already filtered; add the token to `ignore` if a new browser appears |
| Tray icons invisible | tinting disabled | `tinted: true` in `Bar/TrayRow.qml` |
| GPU line missing | no `nvidia-smi` | expected — it hides itself |
| Weather missing | disabled, or request failed | `weather.enabled` in tokens |
| VS Code theme won't apply | high-contrast mode overrides it | also set `workbench.preferredHighContrastColorTheme` |
| One VS Code surface grey | that key is unset or misspelled | add it in `render_vscode()`; VS Code ignores unknown keys |
| Spotify unthemed after update | package upgrade wiped the patch | `spicetify backup apply` — read docs/spotify.md first |
| Spotify has green/warm bits | surface not routed through `--spice-*` | expected; don't add CSS (design.md §8d) |
| Notifications missing | mako owns the DBus name | `pkill -x mako` |
| Clipboard history empty | `wl-paste` watchers not running | `pgrep -af wl-paste` — two expected |
| Screen never locks | hypridle not running | `pgrep -x hypridle` |
| No privilege prompts | no polkit agent | `systemctl --user status hyprpolkitagent` |
| Bluetooth control missing | no controller | `bluetoothctl show` |
| cava draws nothing | plain `cava` reads only the default sink | use `hypr/scripts/cava-launch.sh` |
| `reset-monitors.service` fails | that unit describes my displays | don't link `systemd/`, or delete it |

Shell logs: `quickshell -c gelo` in a terminal, or
`/run/user/1000/quickshell/by-id/*/log.qslog`. Compositor: `hyprctl configerrors`,
`hyprctl layers`.

**Never** `pkill -f <pattern>` where the pattern appears in your own command line
— it kills the shell running it. Use `pkill -x`.

---

## Known gaps

- **No queue in the mini player.** MPRIS exposes one only through the optional
  `TrackList` interface; Spotify reports `HasTrackList = false`, and Quickshell has
  no TrackList binding regardless. Spotify's real queue is Web-API-only and needs
  OAuth.
- **The login screen is built but not enabled.** `sddm/install.sh` works;
  switching display managers can leave you without a graphical login, so it stays
  opt-in.
- **The polkit prompt is stock.** `hyprpolkitagent` exposes nothing to theme, so
  the one authentication dialog in the system does not match it.
- **The wallpaper does not draw behind windows.** It is a background-layer
  surface, so a maximised window occludes it. No fix short of a Hyprland plugin.
- **Both locks are verified.** The shader lock is the default and lives inside
  Quickshell, so it cannot lock a session where the shell is not running.
  `SUPER+SHIFT+L` forces hyprlock, which is standalone. That is what the fallback
  is for.
- **Arch, one machine.** Nothing is distro-specific in principle — QML, GLSL, CSS,
  Python — but every package name, path and verification assumes Arch, Hyprland
  0.56 and Quickshell 0.3.0.
- **Nothing is packaged.** No installer, no `stow`. The symlink loop is the whole
  mechanism, deliberately, so every step is one you can read and undo.
