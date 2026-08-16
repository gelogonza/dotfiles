# dotfiles

A Hyprland desktop built as a design system. One token source drives the bar,
launcher, notifications, lock screen, login screen, terminal, cursor and
wallpaper shader.

The visual language is the **PS3 XMB**: cold silver-blue, one glowing accent,
chrome surfaces, geometric type, and motion that lives in a wave field behind
the interface. Full rationale in **[design.md](design.md)**; what changed and
why in **[docs/CHANGES.md](docs/CHANGES.md)**; what is coming next in
**[docs/roadmap.md](docs/roadmap.md)**.

Picking this up cold — or handing it to someone (or something) else? Start with
**[docs/handoff.md](docs/handoff.md)**. Live at
**[gelogonza.github.io/dotfiles](https://gelogonza.github.io/dotfiles/)**.

MIT licensed — take what you want.

Third-party material: the cursor theme is recoloured from **Adwaita**
(CC-BY-SA 3.0) and is *not* committed here; `design/build-cursor.py` reproduces
it. **Geist** (Vercel, OFL) is fetched at install time rather than vendored.
Early keybind and Quickshell-API reference came from **43PR/dotfiles**; none of
it remains in this tree.

```
design/          token source, generators, shared QML/GLSL/SVG  ← edit here
quickshell/gelo/ the shell — wallpaper, bar, launcher, notifications, power
                 menu, lock, dashboard
hypr/            compositor config, plus hypr/scripts/ (lock, screenshot,
                 colour picker, cava launcher)
sddm/            login theme + installer
ghostty/         terminal
gtk-3.0/ gtk-4.0/ GTK + libadwaita palette overrides
vscode/          generated VS Code theme extension
spicetify/       generated Spotify (spicetify) theme
fastfetch/       fetch tool
cava/            audio visualiser config + its own shaders
docs/            procedures with real failure modes, and the generated site
                 (index/xmb/accessibility/bridge .html — GitHub Pages source)

waybar/ wofi/ mako/   superseded by the shell, kept so the rollback column in
                      "What this replaces" is real rather than aspirational
vlc/ git/ systemd/    incidental config that happens to live in ~/.config;
                      nothing in the design system reads them
```

> `systemd/user/reset-monitors.service` and the `monitor=` lines in
> `hypr/hyprland.conf` describe **my** two displays. Read
> [Before you start](#before-you-start) before linking anything.

---

## Before you start

**This is not a theme you drop in.** The repo *is* `~/.config` — installing it
means pointing ten `~/.config` entries at this tree, which replaces
whatever is at those paths today. Read this section before running anything in
the next one.

**Four things in here describe my machine, not yours.** All four are one-line
fixes, and three of them will make your session look broken if you skip them.

| Where | What | If you don't |
|---|---|---|
| `hypr/hyprland.conf` ~line 14 | `monitor=DP-1` and `monitor=HDMI-A-1` | Wrong resolution, wrong arrangement, or a blank second screen. Run `hyprctl monitors` and replace both lines — `monitor=,preferred,auto,1` works everywhere. |
| `hypr/hyprland.conf` ~line 84 | four `env = …nvidia…` lines | On AMD/Intel these are inert-to-harmful. Comment them out. |
| `systemd/user/reset-monitors.service` | calls a script of mine that isn't in this repo | The unit fails at every login. Don't link `systemd/`, or delete the unit. |
| `hypr/hyprland.conf` `exec-once` block | starts `firefox`, `nm-applet`, `gnome-keyring-daemon` | Harmless, but it launches Firefox on every login. Comment out what you don't want. |

**Back up first.** `ln -sfn` overwrites without asking, and the loops below run
ten times between them.

```bash
cp -a ~/.config ~/.config.bak-$(date +%F)
```

**Have a way back in.** Keep a TTY free (`Ctrl+Alt+F3`) and know that
`Ctrl+Alt+F3` → `rm ~/dotfiles` → log back in returns you to unstyled defaults.
Nothing here touches your display manager unless you explicitly run
`sddm/install.sh`.

**Take pieces instead.** The whole thing is not the only unit of use — the
palette in `design/tokens.json` and everything `design/build-tokens.py` emits
from it (GTK, Ghostty, VS Code, spicetify, Waybar CSS, CSS custom properties)
work on their own with no Hyprland and no Quickshell. `design/build-tokens.py`
then `git status` shows you all 78 outputs.

---

## Requirements

Arch. Everything below is in the official repos except Geist.

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

`quickshell` is in the AUR on some setups (`quickshell-git`); everything else
is in `extra`. Verified against **Hyprland 0.56** and **Quickshell 0.3.0** — the
shell uses `Quickshell.Hyprland`, `WlrLayershell` and `ext-session-lock`, all of
which have moved between releases.

What each of the less obvious ones is for:

- **`python-dateutil`** — recurrence expansion in the dashboard calendar.
  Without it the agenda still works, but a weekly class shows up **once** and
  then never again. Nothing warns you; it just quietly under-reports.
- **`imagemagick`** — the colour swatch in the picker notification and the
  dimensions readout in the screenshot notification.
- **`nautilus`, `pavucontrol`** — what `SUPER+E` and a click on the volume
  control open.
- **`xdg-desktop-portal-hyprland`** — screen sharing and file pickers. Not
  pulled in automatically.

Optional, each of which some part of the UI hides itself over rather than
erroring:

| Package | Enables |
|---|---|
| `cava` | the audio visualiser (see [Changing things](#changing-things) — run it through the launcher) |
| `swappy` | an Annotate button on the screenshot notification |
| `hyprpicker` | `SUPER+SHIFT+C`, the colour picker |
| `bluez bluez-utils blueman` | the Bluetooth control in the bar |
| `nvidia-utils` | the GPU line in the dashboard |
| `sddm` | the login theme — opt-in, see [docs/login-screen.md](docs/login-screen.md) |
| `spicetify-cli` | the Spotify theme |

---

## Install

**1. Clone and link.** The repo *is* your `~/.config`; every app reads it
through a symlink.

```bash
git clone https://github.com/gelogonza/dotfiles ~/Coding/dotfiles-gelo
ln -s ~/Coding/dotfiles-gelo ~/dotfiles

# The desktop itself.
for d in hypr quickshell ghostty fastfetch gtk-3.0 gtk-4.0 cava; do
  ln -sfn ~/dotfiles/$d ~/.config/$d
done

# Superseded, but linking them makes the rollback column in "What this
# replaces" work. Skip freely.
for d in waybar wofi mako; do
  ln -sfn ~/dotfiles/$d ~/.config/$d
done
```

`vlc/`, `git/` and `systemd/` are also in the tree because they live in
`~/.config` on my machine. Nothing in the design system reads them, and
`systemd/` is actively wrong on any machine but mine — link those only if you
have read what is in them.

> The indirection through `~/dotfiles` is deliberate: every `~/.config/*` link
> points there, so the repo can be moved by repointing **one** symlink. Moving
> the repo without updating it leaves every link dangling and a desktop that
> comes up unstyled on the next login. Check them any time with:
>
> ```bash
> find ~/.config -maxdepth 1 -xtype l
> ```
>
> Silence is correct; anything listed is broken.

**2. Make it yours.** The four machine-specific things from
[Before you start](#before-you-start) — monitors, the NVIDIA env block, the
`systemd` unit, the `exec-once` list. Do this now, not after the first login
that comes up wrong.

```bash
hyprctl monitors            # if Hyprland is already running
$EDITOR ~/.config/hypr/hyprland.conf
```

**3. Fonts.** Geist is not packaged for Arch.

```bash
mkdir -p ~/.local/share/fonts
curl -fsSL -o ~/.local/share/fonts/Geist.ttf \
  "https://github.com/google/fonts/raw/main/ofl/geist/Geist%5Bwght%5D.ttf"
fc-cache -f ~/.local/share/fonts
```

**4. Cursor theme.** Not committed — see [design.md §9](design.md).

```bash
design/build-cursor.py
```

**5. Regenerate** (optional on a fresh clone; outputs are committed).

```bash
design/build-tokens.py
design/build-shaders.sh
```

**6. VS Code theme** (optional). Symlink it so regenerating updates it in place:

```bash
ln -sfn ~/dotfiles/vscode/gelo-xmb ~/.vscode/extensions/gelo-xmb
```

Then set **both** of these in `~/.config/Code/User/settings.json` and reload the
window:

```json
"workbench.colorTheme": "gelo XMB",
"workbench.preferredHighContrastColorTheme": "gelo XMB"
```

> Both, not one. Electron reports high contrast on this setup, and when it does
> VS Code ignores `workbench.colorTheme` and follows the high-contrast key
> instead. Setting only the obvious one is a **silent** no-op — no error, no
> notification, the theme just never appears.

**7. Spotify theme** (optional). spicetify **modifies the Spotify install** —
read **[docs/spotify.md](docs/spotify.md)** first; it covers restore and the
one command that destroys your way back to stock.

```bash
ln -sfn ~/dotfiles/spicetify/gelo-xmb ~/.config/spicetify/Themes/gelo-xmb
spicetify config current_theme gelo-xmb color_scheme base
spicetify apply
```

**8. Log out and back in.** Environment variables set in `hyprland.conf`
(`XCURSOR_THEME`) only apply to newly started processes.

**The login screen is a separate, opt-in step** — it means switching display
managers, which can leave you without a graphical login. Read
**[docs/login-screen.md](docs/login-screen.md)** first; it has the TTY recovery
procedure.

### Did it work?

Five checks, in the order things fail:

```bash
find ~/.config -maxdepth 1 -xtype l   # nothing = every link resolves
hyprctl configerrors                  # empty = the compositor is happy
pgrep -x quickshell                   # a PID = the shell is up
fc-list | grep -ci geist              # ≥1 = no tofu in the bar
design/build-tokens.py --check        # exits 0 = generated files match tokens
```

Then, on screen: a bar at the top with a moving wave field behind it, `SUPER+R`
opening the launcher, and a cursor that is silver-blue rather than white. If
the bar is missing, run `quickshell -c gelo` in a terminal and read stderr — a
QML error prints the file and line.

### Then, optionally

**Calendar** — the dashboard says "add `~/.config/gelo/calendars.json`" until
you do. That file is deliberately *outside* the repo; see
[Changing things](#changing-things) for why and what goes in it.

**cava** — install it and alias it to `hypr/scripts/cava-launch.sh`, or it reads
the wrong audio sink. [Changing things](#changing-things) has the alias and the
reason.

**Weather** — off by default. `weather.enabled` in `design/tokens.json`, then
regenerate. Set `weather.location` too; with it empty the API geolocates you by
IP.

---

## What this replaces

| Was | Now | Roll back by |
|---|---|---|
| Waybar | Quickshell bar | comment out `exec-once = quickshell -c gelo`, add `exec-once = waybar` |
| wofi / hyprlauncher | Quickshell launcher | point `$menu` at `wofi --show drun` in `hyprland.conf` |
| mako | Quickshell notifications | uncomment `exec-once = mako` (and stop the shell — see Don't) |
| hyprpaper | shader wallpaper | uncomment `exec-once = hyprpaper` |
| GDM | SDDM (opt-in, not enabled) | [docs/login-screen.md](docs/login-screen.md) |
| Halcyon (VS Code) | generated `gelo XMB` theme | `workbench.colorTheme` + the high-contrast key |
| StarryNight/orange (Spotify) | generated `gelo-xmb` spicetify theme | [docs/spotify.md](docs/spotify.md) |

The commented `exec-once = ~/.local/bin/waybar-launch` line in `hyprland.conf`
refers to a wrapper of mine that is **not** in this repo. `exec-once = waybar`
is the equivalent that works on a fresh clone.

**Every compositor-side change lives in `hypr/gelo.conf`**, sourced by one line
at the bottom of `hyprland.conf`. Delete that line to revert all of them at once.

---

## The bar

```
[ workspaces | launchers | now playing ]   [ date  time ]   [ weather | tray | vol  bt  awake  power ]
                                   [ window title ]
```

- **Workspaces** — click to switch. The active one is a travelling blob that
  stretches as it moves and fires a ripple into the wallpaper behind it.
- **Launchers** — Ghostty, VS Code, Chrome, Obsidian, Blender. Edit the `apps`
  list in `quickshell/gelo/Bar/AppLaunchers.qml`.
- **Now playing** — whatever MPRIS player is actually playing, with a
  play/pause toggle. Click the title to raise the player. Hidden when nothing
  is loaded.
- **Volume** — click to open `pavucontrol`, drag the track to set the level,
  scroll to nudge it, right-click to mute.
- **Bluetooth** — click to open `blueman-manager`, right-click to disconnect
  every connected device. Hidden entirely if the machine has no controller.
- **Keep awake** — the crescent moon. Crossed out and in full ink means the
  machine will not idle-lock; it holds a logind idle inhibitor for as long as
  it is on, and the inhibitor dies with the shell so it cannot get stuck.
- **Power** — opens a menu: lock, sleep, log out, reboot, shut down. Sleep
  locks on the way down, so the machine never resumes to an open desktop.

### Keybinds

| Key | Action |
|---|---|
| `SUPER + R` / `SUPER + D` | command palette |
| `SUPER + L` | lock (Quickshell shader lock, falls back to hyprlock) |
| `SUPER + SHIFT + L` | lock (hyprlock — standalone, no shell dependency) |
| `SUPER + Q` / `SUPER + Return` | terminal (new window) |
| `SUPER + C` | close window (no confirm prompt — `confirm-close-surface = false`) |
| `SUPER + E` | file manager (Nautilus) |
| `SUPER + SHIFT + V` | clipboard history |
| `SUPER + SHIFT + N` | notification history |
| `SUPER + SHIFT + I` | keep the screen awake (toggle) |
| `SUPER + SHIFT + D` | dashboard (or click the clock) |
| `SUPER + Tab` / `ALT + Tab` | window switcher |
| `SUPER + S` / `Print` | screenshot a region |
| `SUPER + SHIFT + S` | screenshot everything |
| `SUPER + ALT + S` | screenshot a window (snaps to window edges) |
| `SUPER + SHIFT + C` | pick a colour — hex to clipboard, names the nearest token |
| `SUPER + 1..0` | switch workspace |
| `SUPER + SHIFT + 1..0` | move window to workspace |
| `SUPER + \`` / `SUPER + SHIFT + \`` | scratchpad — toggle / send window to it |
| `SUPER + V` | float the window |
| `SUPER + arrows` | move focus |
| `SUPER + drag` / `SUPER + right-drag` | move / resize the window |

**Clipboard and notification history** live in the launcher rather than
separate pickers — same fuzzy search, same chrome. Selecting a notification
copies its text, which is what you almost always went back for. `SUPER+SHIFT+V`
rather than `SUPER+V` because `SUPER+V` is already `togglefloating`, and
Hyprland fires *both* bindings for a chord instead of picking one. Swap them in
`hyprland.conf` if you prefer.

**The scratchpad is on `` SUPER+` ``, not `SUPER+S`** — stock Hyprland puts it
on S, which is where the screenshot binds went, and by that same
fires-both-bindings rule `SUPER+S` was starting a region selection *and*
toggling the scratchpad underneath it. If you are diffing against the default
config, that is the deliberate difference. `hyprctl binds` is how you check for
the rest: two entries with the same `modmask` and `key` is always a collision,
never a precedence.

**Idle**: locks at 5 minutes, displays off at 10 (`hypr/hypridle.conf`). It
calls `hypr/scripts/lock.sh`, the same entry point as the keybind and the power
menu, so there is one answer to "which lock do I get" instead of four.

The launcher is also scriptable:

```bash
qs -c gelo ipc call launcher toggle
qs -c gelo ipc call launcher search fire
qs -c gelo ipc call launcher clipboard
qs -c gelo ipc call launcher notifications
qs -c gelo ipc call launcher windows
qs -c gelo ipc call power toggle
qs -c gelo ipc call idle toggle      # or on / off / status
qs -c gelo ipc call dashboard toggle
```

---

## Changing things

**Colour, type, spacing, motion, materials — all of it:**

```bash
$EDITOR design/tokens.json
design/build-tokens.py
design/build-shaders.sh          # if you touched colours the shader reads
design/build-cursor.py           # if you touched the accent
sudo sddm/install.sh             # if the login theme is installed
```

Then restart the shell:

```bash
pkill -x quickshell; setsid quickshell -c gelo >/dev/null 2>&1 &
```

**GTK apps** (Nautilus, file dialogs) follow the palette through
`@define-color` overrides generated into `gtk-4.0/gtk.css`. libadwaita ignores
custom *themes* by design, but it does read those named colours — that is the
supported way to retheme it. Restart the app to pick up changes.

**cava** — run it through the launcher, not directly:

```bash
~/dotfiles/hypr/scripts/cava-launch.sh
```

cava's `source` is static and a monitor only carries audio played to *that*
sink, so any fixed choice is wrong half the time on a machine that moves
between USB speakers and Bluetooth headphones. The launcher resolves the sink
at start-up — a stream that is actually playing, else a RUNNING sink, else the
default — so it follows whatever you are listening on. Worth an alias:

```bash
echo "alias cava='~/dotfiles/hypr/scripts/cava-launch.sh'" >> ~/.zshrc
```

**Switch the font** — one line in `tokens.json`. Figtree, Inter Display and
Nimbus Sans are already installed as alternatives.

**Dashboard** — click the clock or `SUPER+SHIFT+D`: month calendar, upcoming
events, weather, and CPU/MEM/GPU. Those three used to sit in the bar
permanently; a number you never read is texture, so they moved behind a
gesture and the bar got quieter.

**Calendar** — Google and Outlook each publish a *secret ICS address* per
calendar (Google: Settings → calendar → "Secret address in iCal format";
Outlook: Settings → Calendar → Shared calendars → Publish). No OAuth, no app
registration. Put them in `~/.config/gelo/calendars.json`:

```json
[
  { "name": "personal", "url": "https://calendar.google.com/…/basic.ics" },
  { "name": "school",   "url": "https://outlook.office365.com/…/calendar.ics" }
]
```

> **That file is deliberately outside this repo.** The repo *is* `~/.config`
> and is pushed to GitHub; those URLs are bearer secrets — anyone with the link
> reads your calendar. Nothing in the shell ever prints one, including on error:
> a failed feed reports `name: ExceptionType` and nothing else. `calendars.json`
> is in `.gitignore` as well, belt and braces, in case that file ever moves.

```bash
mkdir -p ~/.config/gelo && chmod 700 ~/.config/gelo
$EDITOR ~/.config/gelo/calendars.json
chmod 600 ~/.config/gelo/calendars.json
```

Recurrence needs `python-dateutil`. Without it the feed still parses, but a
weekly class appears once and then vanishes — the failure is silent and looks
like an empty week rather than a missing package.

**Enable weather** — off by default, because it sends a request to a
third-party server every 15 minutes and, with no location set, that server
geolocates you by IP. Set `weather.enabled` and preferably an explicit
`weather.location` (a city name is coarser than your IP).

---

## Do / don't

**Do**

- Edit `design/tokens.json` and regenerate.
- Edit `design/qml/*` for shared components, `design/shaders/*` for shaders,
  `design/icons/*` for icons — then regenerate.
- Run `design/build-tokens.py --check` before committing; it fails if any
  generated file is stale.
- Run `design/build-tokens.py --audit` after any colour change. It measures all
  35 text/surface pairs against WCAG and exits non-zero on a failure — the last
  time a palette moved, one token silently dropped below AA on three surfaces
  and nothing else would have caught it.
- Keep a rescue TTY (`Ctrl+Alt+F3`) available the first time you touch the lock
  screen or the display manager. **Not F2** — the graphical session usually
  holds VT2, so F2 returns you to the locked screen rather than to a shell.
  `loginctl show-session $XDG_SESSION_ID -p VTNr` tells you which one you are
  on; pick any other.

**Don't**

- **Don't edit any file with a `GENERATED FILE — DO NOT EDIT` banner.** Your
  change is one regenerate away from being erased. Edit the source in `design/`.
- **Don't edit `quickshell/gelo/Components/*`, `*/Shaders/*` or `*/icons/*`** —
  those are copies. The originals live in `design/`.
- **Don't move the repo** without repointing `~/dotfiles`.
- **Don't add a fourth accent location.** See design.md §3.
- **Don't run mako alongside the shell.** `org.freedesktop.Notifications` is a
  single-owner DBus name — whichever starts first wins and the other silently
  does nothing.
- **Don't enable blur on the shell layer surfaces.** It softens the hairline and
  washes out the glow, which are the two things carrying the material.
- **Don't `systemctl stop gdm`** while logged in — that kills your session.
  Switch display managers, then reboot.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Desktop comes up unstyled | `~/dotfiles` doesn't resolve | `ln -s <repo> ~/dotfiles`, then `find ~/.config -maxdepth 1 -xtype l` |
| Bar missing entirely | shell not running, or a QML error | run `quickshell -c gelo` and read stderr |
| Wrong resolution, or a black second screen | the `monitor=` lines are mine | `hyprctl monitors`, then edit `hypr/hyprland.conf` |
| Session won't start on AMD/Intel | the NVIDIA `env` block | comment out the four `env = …nvidia…` lines |
| A recurring event shows once, then never | `python-dateutil` missing | `sudo pacman -S python-dateutil` — nothing warns you |
| Calendar card says "add calendars.json" | no feeds configured | it is doing the right thing; see [Changing things](#changing-things) |
| Calendar says "Could not read …" | bad or expired ICS URL | a `ValueError` there usually means the placeholder is still in the file |
| `reset-monitors.service` fails at login | that unit describes my displays | don't link `systemd/`, or delete the unit |
| Boxes instead of glyphs | Geist not installed | install fonts, then `fc-cache -f` |
| Wallpaper is a flat colour | shader not baked | `design/build-shaders.sh` |
| Old cursor still showing | env vars only apply to new processes | log out and back in |
| Tray icons invisible | tinting disabled | `tinted: true` in `Bar/TrayRow.qml` |
| GPU stat missing | no `nvidia-smi` | expected — it hides itself |
| Weather missing | disabled, or the request failed | `weather.enabled` in tokens |
| VS Code theme won't apply | high-contrast mode overrides it | also set `workbench.preferredHighContrastColorTheme` |
| One VS Code surface is grey | that colour key is unset or misspelled | add it in `render_vscode()`; VS Code ignores unknown keys |
| Spotify unthemed after an update | package upgrade wiped the patch | see docs/spotify.md — `spicetify backup apply` |
| Spotify still has green/warm bits | surface not routed through `--spice-*` | expected; don't add CSS (design.md §8d) |
| Notifications not appearing | mako owns the DBus name | `pkill mako` |
| Clipboard history empty | `wl-paste` watchers not running | `pgrep -af wl-paste` — two expected |
| Screenshot has no Annotate button | no annotator installed | `sudo pacman -S swappy` — the button appears by itself |
| Screen never locks itself | hypridle not running | `pgrep -x hypridle`; check `hypr/hypridle.conf` |
| Privilege prompts never appear | no polkit agent | `systemctl --user status hyprpolkitagent` |
| Bluetooth control missing | no controller, or `bluetoothctl` absent | `bluetoothctl show` |
| cava draws nothing | run it via `hypr/scripts/cava-launch.sh` — plain `cava` reads only the **default** sink | see below |

Shell logs: run `quickshell -c gelo` in a terminal, or read
`/run/user/1000/quickshell/by-id/*/log.qslog`.

Compositor: `hyprctl configerrors`, `hyprctl layers`.

---

## Known gaps

- **Both locks are verified.** The Quickshell lock (with the shader) is the
  default — `SUPER+L`, the power menu, and the 5-minute idle timeout all go
  through `hypr/scripts/lock.sh`. `SUPER+SHIFT+L` forces **hyprlock**, which is
  a standalone binary and the one to reach for if the shell is unwell: the
  shader lock lives *inside* Quickshell, so it cannot lock a session where the
  shell is not running. That is what the fallback is for.

- **The login screen is built but not enabled.** `sddm/` is complete and
  `sddm/install.sh` works; switching display managers is a step that can leave
  you without a graphical login, so it stays opt-in behind
  [docs/login-screen.md](docs/login-screen.md).

- **The polkit prompt is stock.** `hyprpolkitagent` renders its own dialog and
  exposes nothing to theme, so the one authentication prompt in the system does
  not match the rest of it.

- **The wallpaper does not draw behind windows.** It is a layer surface on the
  background layer, so a maximised window occludes it entirely — the wave field
  is context around the interface, not a live backdrop through it. There is no
  compositor-side fix short of rendering the shader as a Hyprland plugin.

- **Arch only, and one machine's worth of testing.** Nothing here is
  distro-specific in principle — it is QML, GLSL, CSS and Python — but the
  package names, the paths and every verification in
  [docs/](docs/handoff.md) assume Arch, Hyprland 0.56 and Quickshell 0.3.0.

- **Nothing is packaged.** No installer, no `stow`, no bootstrap script. The
  symlink loop in [Install](#install) is the whole mechanism, deliberately, so
  that every step is one you can read and undo.