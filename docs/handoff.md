# Handoff

Read this first if you are picking this project up cold. It is the context that
is **not** recoverable from the code or the git history.

Order to read: this file → `design.md` (the system and its rules) →
`docs/roadmap.md` (what is next) → `README.md` (setup, do/don't).

---

## What this is

A Hyprland desktop built as a design system, for **gelo** — a design engineer.
It doubles as a portfolio piece, so *why* a thing looks the way it does matters
as much as that it works.

One file, `design/tokens.json`, generates everything: the shell, the login
theme, the terminal, GTK apps, the editor, Spotify, the compositor colours, the
cursor. Across six target formats.

Reference is the **PS3 XMB**: cold silver-blue, one glowing accent, chrome
surfaces, geometric type, and motion that lives in a wave field *behind* the
interface rather than in the interface.

## The stack, in one breath

Hyprland 0.56 · Quickshell 0.3.0 (the whole shell — bar, launcher,
notifications, power menu, lock, wallpaper) · SDDM login theme (installed, not
enabled) · hyprlock + a second Quickshell lock · ghostty · Geist ·
Nautilus · two 1440p monitors (HDMI-A-1 left @100Hz, DP-1 right @144Hz) ·
NVIDIA RTX 3070.

---

## How gelo wants you to work

These are stated preferences, not guesses:

1. **Do not commit unless asked.** Finish the work, leave it in the tree, say it
   is ready. An explicit "commit this" covers that request only, not the rest of
   the session.
2. **Conventional Commits** — `type(scope): subject`, imperative, concise body.
   Keep the body to what the diff does not show: the cause of a bug, the reason
   for a non-obvious choice, a risk.
3. **He pushes himself.** `origin/master` moving is him, not you.
4. He iterates on visuals hard — expect "that's too much", "make it thicker",
   "I liked the old one". Do not treat a previous decision as settled.

## How to actually verify work here

This is a *visual* project on a *live* machine. The habit that has caught the
most real bugs:

- **Screenshot and measure, do not eyeball.** `grim -g "<x>,<y> <w>x<h>"`, then
  compare pixels in Python. Two examples that only measurement caught: a shader
  that rendered **zero changed pixels over 30 seconds** (looked fine in a
  screenshot, was a still image in motion), and a glow that measured
  `(107,128,151)` grey instead of the accent `(52,120,196)`.
- **Get geometry from the compositor**, not by guessing:
  `hyprctl layers -j`, `hyprctl clients -j`, `hyprctl monitors -j`. Surfaces sit
  under the bar's exclusive zone (y≈56) and the second monitor is at x=-2560 —
  guessing coordinates has wasted several rounds.
- **Restart the shell to test**:
  `pkill -x quickshell; setsid quickshell -c gelo >/tmp/qs.log 2>&1 & disown`,
  then grep the log. Zero warnings is the bar.
- **Before committing**: `design/build-tokens.py --check`, `qmllint` over every
  QML file, `hyprctl configerrors`.

⚠️ **Do not use `pkill -f <pattern>`** where the pattern appears in your own
command line — it kills your own shell and returns exit 144. Use `pkill -x`.

⚠️ **This is his live desktop.** Do not steal focus, switch workspaces, or lock
the screen without a reason and a way back. Restore anything you change.

---

## Traps specific to this machine

Three Quickshell services **return no data here** even though the underlying
system works. The established pattern is: probe the service first, and if it is
empty, drive the underlying tool and keep the API shape.

| Service | Symptom | What is used instead |
|---|---|---|
| `DesktopEntries` | empty model, `byId()`/`heuristicLookup()` null | `scripts/list-apps.py` |
| `Bluetooth` | null adapter, zero devices | `scripts/bluetooth.sh` (bluetoothctl) |
| icon theme lookup | `iconPath()` empty for every status glyph | our own SVGs in `design/icons/` |

Other landmines, all of which have already cost time:

- **QML uniform arrays never bind.** `vec4 ripples[4]` cannot receive data —
  Qt 6 matches uniform-block members to QML properties *by name*, and an array
  member has no matchable name. It fails silently. Use `rippleA`, `rippleB`, …
- **`item.Window.window` is null inside a Quickshell layer surface.**
  `PanelWindow` is not a plain `QQuickWindow`. Pass the window explicitly.
  `mapToGlobal` also ignores layer margins.
- **A token named `on-*` breaks the whole Tokens singleton.** `on-accent` →
  `onAccent`, which QML parses as a signal handler. The generator now rejects
  this, but the error message points at the line and never the cause.
- **Never put `brightness` on a tint `MultiEffect`** — it blows out bright
  sources. Tray icons came back as pale washes.
- **`build-shaders.sh` compiles the *generated* copies.** It now runs
  `build-tokens.py` first; do not "optimise" that away.
- **libadwaita ignores custom themes** — it reads named colours from
  `gtk-4.0/gtk.css` only.
- **VS Code ignores `workbench.colorTheme` on this machine.** Something reports
  high contrast to Electron, so it obeys
  `workbench.preferredHighContrastColorTheme` instead. Setting a theme the
  obvious way is a silent no-op. Set both keys.
- **VS Code silently drops unrecognised colour keys.** A mistyped key is not an
  error, it is one surface stuck on stock grey. Grep the shipped bundle
  (`/usr/share/code/resources/app/out/vs/workbench/workbench.desktop.main.js`,
  plus `resources/app/extensions/*/package.json` for `gitDecoration.*`).

---

## State as of this handoff

**Committed and working:** bar (workspaces + launchers + clock/title + weather,
CPU/MEM/GPU, git, tray, volume/bluetooth/power), command palette with app and
clipboard modes, notifications, wallpaper shader with a ripple bus, cursor
theme, terminal, GTK theming, idle daemon, polkit agent, power menu with sleep.

**Uncommitted:**

- `vscode/` and the VS Code renderer in `design/build-tokens.py` — now
  **installed and verified** (roadmap 1.1). 277 colours, 21 scopes, every key
  validated against VS Code's registry, every text pair measured at AA or
  better. `~/.vscode/extensions/gelo-xmb` is a symlink into the repo.
- `spicetify/` and `docs/spotify.md` — **applied and verified** (roadmap 1.3).
  Three layers: `color.ini` is the theme, `user.css` adds chrome/glow,
  `theme.js` runs the XMB shader behind the app and ripples it on the beat.
  The last two are **optional** — on breakage delete `theme.js` first, then
  `user.css`, re-applying after each. Live tuning: profile menu → XMB field,
  or Ctrl+Alt+X (not Ctrl+Shift+X, which is Spotify's Connect panel).
  Spotify was on StarryNight/orange, the last warm hue in the system.
  `~/.config/spicetify/Themes/gelo-xmb` is a symlink into the repo.
  ⚠️ **Read `docs/spotify.md` before running any spicetify command** —
  `spicetify backup` on an already-patched install destroys your way back to
  stock Spotify.

**Untested and it matters:**

- **Both locks are verified** (gelo, 2026-08-15). The Quickshell shader lock is
  the default via `hypr/scripts/lock.sh`, which falls back to hyprlock when the
  shell is not running — the shader lock lives inside Quickshell and cannot
  lock a session without it. `SUPER+SHIFT+L` forces hyprlock.
- SDDM login theme is installed but not enabled (`docs/login-screen.md`).

---

## The rules that constrain design decisions

From `design.md §10`. Breaking one of these is a redesign, not a tweak:

1. **Accent in exactly three places**: workspace indicator, focused window
   border, cursor. Two sanctioned exceptions — the transient ripple wavefront,
   and terminal ANSI 1/3/9/11 where red/yellow are load-bearing semantics.
2. **No warm hues** otherwise. The absence of orange/coral/amber is the whole
   reason this does not read as a generic product palette.
3. **4px grid**, everywhere.
4. **Weight never above 400.** Hierarchy comes from size, opacity, tracking and
   glow — Geist is variable, but 500+ is out.
5. **No backdrop blur on shell surfaces** — it kills the hairline and the glow.
   Blur is on for *translucent windows* (the terminal) only.
6. **Never edit a generated file.** Sources live in `design/`.
7. **Surfaces you work *in* are dark; chrome you work *with* is light.** This is
   why the terminal is dark navy on a light desktop, and why the VS Code theme
   derives from the `terminal` token block rather than the UI palette.

## Where things live

```
design/tokens.json        the single source of truth
design/build-tokens.py    generates everything; --check fails on staleness
design/qml/               shared components (Chrome, Glow, Reflection, Icon)
design/shaders/xmb.frag   the wave field, used by wallpaper + login + lock
design/icons/             our own SVG glyph set
quickshell/gelo/          the shell
  Bar/ Launcher/ Notifications/ PowerMenu/ Lock/ Wallpaper/ Services/ scripts/
hypr/                     hyprland.conf + gelo.conf (all compositor changes)
docs/                     CHANGES, roadmap, lock-screen, login-screen, handoff
```

`docs/CHANGES.md` is the long-form build log — every non-obvious decision and
every failed approach, recorded so they are not retried.
