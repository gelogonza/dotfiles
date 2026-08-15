# dotfiles

A Hyprland desktop built as a design system. One token source drives the bar,
launcher, notifications, lock screen, login screen, terminal, cursor and
wallpaper shader.

The visual language is the **PS3 XMB**: cold silver-blue, one glowing accent,
chrome surfaces, geometric type, and motion that lives in a wave field behind
the interface. Full rationale in **[design.md](design.md)**; what changed and
why in **[docs/CHANGES.md](docs/CHANGES.md)**.

```
design/          token source, generators, shared QML/GLSL/SVG
quickshell/gelo/ the shell — wallpaper, bar, launcher, notifications, power menu
sddm/            login theme + installer
hypr/            compositor config
ghostty/         terminal
fastfetch/       fetch tool
docs/            procedures with real failure modes
reference/       upstream 43PR material, not loaded at runtime
```

---

## Requirements

Arch. Everything below is in the official repos except the fonts.

```bash
sudo pacman -S --needed \
  hyprland quickshell qt6-shadertools qt6-wayland qt6-5compat qt6-declarative \
  hyprlock ghostty fastfetch \
  grim slurp cliphist wl-clipboard brightnessctl playerctl jq \
  pipewire pipewire-pulse wireplumber \
  adwaita-cursors inter-font
```

Optional: `sddm` (login screen), `nvidia-utils` (the GPU stat hides itself
without it), `bluez bluez-utils` (the Bluetooth control hides itself without a
radio).

---

## Install

**1. Clone and link.** The repo *is* your `~/.config`; every app reads it
through a symlink.

```bash
git clone https://github.com/gelogonza/dotfiles ~/Coding/dotfiles-gelo
ln -s ~/Coding/dotfiles-gelo ~/dotfiles

for d in hypr quickshell ghostty fastfetch gtk-3.0 gtk-4.0 mako cava wofi; do
  ln -sfn ~/dotfiles/$d ~/.config/$d
done
```

> The indirection through `~/dotfiles` is deliberate: every `~/.config/*` link
> points there, so the repo can be moved by repointing **one** symlink. Moving
> the repo without updating it leaves 13 dangling links and a desktop that comes
> up unstyled on the next login.

**2. Fonts.** Geist is not packaged for Arch.

```bash
mkdir -p ~/.local/share/fonts
curl -fsSL -o ~/.local/share/fonts/Geist.ttf \
  "https://github.com/google/fonts/raw/main/ofl/geist/Geist%5Bwght%5D.ttf"
fc-cache -f ~/.local/share/fonts
```

**3. Cursor theme.** Not committed — see [design.md §9](design.md).

```bash
design/build-cursor.py
```

**4. Regenerate** (optional on a fresh clone; outputs are committed).

```bash
design/build-tokens.py
design/build-shaders.sh
```

**5. Log out and back in.** Environment variables set in `hyprland.conf`
(`XCURSOR_THEME`) only apply to newly started processes.

**The login screen is a separate, opt-in step** — it means switching display
managers, which can leave you without a graphical login. Read
**[docs/login-screen.md](docs/login-screen.md)** first; it has the TTY recovery
procedure.

---

## What this replaces

| Was | Now | Roll back by |
|---|---|---|
| Waybar | Quickshell bar | uncomment `waybar-launch` in `hyprland.conf` |
| wofi / hyprlauncher | Quickshell launcher | `$menu` in `hyprland.conf` |
| mako | Quickshell notifications | uncomment `exec-once = mako` |
| hyprpaper | shader wallpaper | uncomment `exec-once = hyprpaper` |
| GDM | SDDM (opt-in, not enabled) | docs/login-screen.md |

**Every compositor-side change lives in `hypr/gelo.conf`**, sourced by one line
at the bottom of `hyprland.conf`. Delete that line to revert all of them at once.

---

## The bar

```
[ workspaces | app launchers ]     [ date  time ]     [ weather | CPU MEM GPU | git | tray | vol  bt  power ]
                                   [ window title ]
```

- **Workspaces** — click to switch. The active one is a travelling blob that
  stretches as it moves and fires a ripple into the wallpaper behind it.
- **Launchers** — Ghostty, VS Code, Chrome, Obsidian, Blender. Edit the `apps`
  list in `quickshell/gelo/Bar/AppLaunchers.qml`.
- **Git** — resolves the repo from the *focused window* by walking its process
  tree, so a terminal sitting in `$HOME` still shows the project its shell is in.
- **Volume** — click to open `pavucontrol`, drag the track to set the level,
  scroll to nudge it, right-click to mute.
- **Bluetooth** — click to open `blueman-manager`, right-click to disconnect
  every connected device. Hidden entirely if the machine has no controller.
- **Power** — opens a menu: lock, log out, reboot, shut down.

### Keybinds

| Key | Action |
|---|---|
| `SUPER + R` / `SUPER + D` | command palette |
| `SUPER + L` | lock (hyprlock) |
| `SUPER + SHIFT + L` | lock (Quickshell, shader — **untested**, see docs/lock-screen.md) |
| `SUPER + Q` / `SUPER + Return` | terminal |
| `SUPER + C` | close window |
| `SUPER + 1..0` | switch workspace |
| `SUPER + SHIFT + 1..0` | move window to workspace |

The launcher is also scriptable:

```bash
qs -c gelo ipc call launcher toggle
qs -c gelo ipc call launcher search fire
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

**Switch the font** — one line in `tokens.json`. Figtree, Inter Display and
Nimbus Sans are already installed as alternatives.

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
- Keep a TTY (`Ctrl+Alt+F2`) available the first time you touch the lock screen
  or the display manager.

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
| Desktop comes up unstyled | `~/dotfiles` doesn't resolve | `ln -s <repo> ~/dotfiles` |
| Bar missing entirely | shell not running, or a QML error | run `quickshell -c gelo` and read stderr |
| Boxes instead of glyphs | Geist not installed | install fonts, then `fc-cache -f` |
| Wallpaper is a flat colour | shader not baked | `design/build-shaders.sh` |
| Old cursor still showing | env vars only apply to new processes | log out and back in |
| Tray icons invisible | tinting disabled | `tinted: true` in `Bar/TrayRow.qml` |
| GPU stat missing | no `nvidia-smi` | expected — it hides itself |
| Weather missing | disabled, or the request failed | `weather.enabled` in tokens |
| Notifications not appearing | mako owns the DBus name | `pkill mako` |
| Bluetooth control missing | no controller, or `bluetoothctl` absent | `bluetoothctl show` |

Shell logs: run `quickshell -c gelo` in a terminal, or read
`/run/user/1000/quickshell/by-id/*/log.qslog`.

Compositor: `hyprctl configerrors`, `hyprctl layers`.

---

## Known gaps

- **Neither lock has been through a real lock/unlock cycle.** hyprlock is bound
  to `SUPER+L`; the Quickshell lock (with the shader) is on `SUPER+SHIFT+L`.
  The latter's PAM path is verified to prompt and to reject a wrong password,
  but only your real password can prove it unlocks. Read
  **[docs/lock-screen.md](docs/lock-screen.md)** and test with a TTY open before
  relying on either.
- **The wallpaper shader does not stop when occluded.** wlr-layer-shell exposes
  no occlusion signal, so it keeps rendering behind maximised windows. If
  battery or thermals matter, replace the `Wallpaper{}` block in `shell.qml`
  with a static image rather than micro-optimising the GLSL.
- **Quickshell's `DesktopEntries` returns nothing** on this system, which is why
  the launcher builds its own index via `scripts/list-apps.py`.
- **The fastfetch logo path points outside the repo** and renders nothing on a
  fresh clone.
