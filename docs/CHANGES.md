# Build log — Hyprland design-engineering rice

Everything changed in the first build session, why, and how to undo it.

Tier achieved: **1 (Quickshell)**. No fallback to AGS or animated-Waybar was
needed. `quickshell 0.3.0` turned out to be in Arch's official `extra` repo, not
the AUR, so the full `ShaderEffect` path was available from the start.

---

## 0. Pre-existing breakage found and fixed

**Every `~/.config/*` symlink was dangling.** All 13 of them pointed at
`~/dotfiles`, which stopped existing when the repo was moved to
`~/Coding/dotfiles-gelo`. The desktop only still looked correct because
Hyprland had loaded its config before the move — the next restart would have
come up unstyled.

Fixed by symlinking `~/dotfiles` → the repo, so all existing links resolve
again without touching any of them individually.

**There was no lock keybind.** Nothing in `hyprland.conf` bound `hyprlock`;
the session could not be locked at all. Now `SUPER+L`.

---

## 1. Repo structure

```
design/          token source, generator, shared QML + GLSL
quickshell/gelo/ the shell (wallpaper, bar, launcher, notifications)
sddm/            login theme + installer
hypr/            compositor config
docs/            procedures
reference/       extracted 43PR material, not loaded at runtime
```

Kept the existing convention: `~/.config/<x>` → `<repo>/<x>`. Added
`~/.config/quickshell` → `<repo>/quickshell`.

From **43PR/dotfiles**: keybind inventory, their `hyprquickpaper` Quickshell
config (used as a working reference for the Quickshell API surface), and their
hyprlock config, all extracted into `reference/`. None of it is loaded at
runtime. Their Waybar/Rofi CSS was not used, as planned. The clone itself is
gitignored — it carries its own `.git` and would otherwise nest a repo.

---

## 2. Design token system

`design/tokens.json` is the single source of truth.
`design/build-tokens.py` generates **ten** files:

| Generated | Consumer |
|---|---|
| `quickshell/gelo/Theme/Tokens.qml` | shell |
| `quickshell/gelo/Theme/qmldir` | shell |
| `sddm/themes/gelo-liquid/Theme/Tokens.qml` | login theme |
| `sddm/themes/gelo-liquid/Theme/qmldir` | login theme |
| `design/tokens.css` | GTK / Waybar fallback tier |
| `hypr/tokens.conf` | `hyprland.conf`, `hyprlock.conf` |
| `quickshell/gelo/Components/Glass.qml` | shell |
| `sddm/themes/gelo-liquid/Components/Glass.qml` | login theme |
| `quickshell/gelo/Shaders/fluid.frag` | shell |
| `sddm/themes/gelo-liquid/Shaders/fluid.frag` | login theme |

**Why a generator rather than one shared file:** there are four target languages
(QML, CSS, hyprlang) and *two QML roots that cannot import each other*. The SDDM
theme installs to `/usr/share/sddm/themes` and runs as the unix user `sddm`;
`/home/gelo` is mode `700`, so the greeter physically cannot read anything in
`$HOME`. Shared components and shaders are therefore copied into each root with
their import paths rewritten, rather than referenced.

`--check` mode fails on staleness for CI/pre-commit. All outputs are committed
so a fresh clone works without running anything.

---

## 3. Bar

`quickshell/gelo/Bar/` — workspaces, window title, git context, tray, clock.

**Blob morph.** The active workspace indicator tracks its two edges as
independent animated values with different durations: the leading edge is fast,
the trailing edge slow. It stretches across the gap, then settles. Measured
through a real workspace switch: **24px → 37px → 24px**. A sliding rectangle
would hold 24 throughout.

**Git module.** Resolves the repo from the focused window by walking its process
tree *shallowest-first*, capped at 4 levels. A terminal sitting in `$HOME`
correctly falls through to the shell one level down that is `cd`'d into the
project, while an unrelated deep descendant (language server, build tool that
chdir'd elsewhere) can never outrank it. Verified: VS Code → `master +9
49a590b`, Chrome → nothing.

The script resolves the focused pid itself via `hyprctl` rather than taking it
from QML — Quickshell's `HyprlandToplevel` carries the title immediately but
only exposes a pid after an async `refreshToplevels()`.

**Bug found during build:** the specular highlight was centre-peaked, which is
invisible on a 2528px-wide bar where every visible pixel is far from the peak.
Changed to hold across the span and fade only at the ends (+16 luminance over
the body, was +5).

---

## 4. Launcher

`quickshell/gelo/Launcher/` — command palette on `SUPER+R` and `SUPER+D`.

**Quickshell's `DesktopEntries` returns an empty model on this system** — both
`byId()` and `heuristicLookup()` return null even with `XDG_DATA_HOME` and
`XDG_DATA_DIRS` set explicitly. The launcher builds its own index via
`scripts/list-apps.py` (83 apps in 27ms), which is the better architecture for a
palette anyway since it has to mix applications with commands.

Fuzzy subsequence ranking with bonuses for word-start matches, contiguous runs,
and short names. `fire` → Firefox first by prefix.

Exposed over IPC, so it is scriptable and bindable:
`qs -c gelo ipc call launcher {toggle,open,close,search <q>}`.

**Bug found during build:** reopening after a search showed stale text above
unfiltered results — `show()` reset `Apps.query` but not the field. The field is
the source of truth; clearing it is what pushes the query down.

---

## 5. Login screen (SDDM)

`sddm/themes/gelo-liquid/` — the one surface with a real GLSL shader.

Domain-warped fBm fluid field, baked to `.qsb` (Qt 6 will not accept raw GLSL at
runtime). Clock in Inter at display size, glass password field, blob pulse on
submit, decaying shake plus accent-tinted pulse on failure. No new hue is
introduced for the failure state.

**The most important finding of the build.** At the originally-specced ambient
speed (`0.06`), the shader measured **zero changed pixels over 30 seconds**. The
palette spans only 13–42 in 8-bit, so the motion quantised away entirely and it
rendered a still image — it would have photographed as a working shader and been
a lie in motion. Fixed by raising the rate to `0.28` and adding `--border` as a
fourth tonal stop to widen the usable range ~60%. Now ~90% of pixels change over
4 seconds.

The rate now lives in QML rather than the shader, so the login screen and the
desktop wallpaper share one shader at different speeds.

**Not yet active.** `sudo sddm/install.sh` installs the theme and stops; it does
not switch display managers. See `docs/login-screen.md` for the switch, the TTY
recovery procedure, and a symptom→cause table.

---

## 6. Lock screen

`hypr/hyprlock.conf` — deliberately plain: blurred screenshot background, glass
on the password field only, no shader. This is the path back into a running
session and should feel instant.

**Unverified.** hyprlock has no dry-run mode and a failed lock can leave a
session locked. Sandboxing it in a nested headless Hyprland was attempted and
abandoned (the headless backend will not start here). Test deliberately with
`hyprlock --grace 30`, which lets any keypress dismiss it without a password,
and keep a TTY available.

---

## 7. Notifications

`quickshell/gelo/Notifications/` — glass cards, slide in from the right, drag or
click to dismiss with squash-and-release. Critical notifications persist until
acknowledged; everything else auto-clears.

**Two bugs found during build:**
- `opacity` referenced itself (entrance animation vs drag fade) — split into a
  separate `revealed` property that the drag fade multiplies into.
- Nothing rendered at first: Quickshell delivers notifications *untracked* and
  discards them unless the handler sets `notification.tracked = true`.

---

## 8. Wallpaper

`quickshell/gelo/Wallpaper/` — the same fluid shader on the background layer,
slower than the login variant (0.16 vs 0.28 units/sec).

**This is load-bearing for the material, not decoration.** The glass gets its
frost from the compositor blurring whatever is behind it. Over the previous
near-black wallpaper the bar measured 17/255 mean brightness and read as flat
paint; over the shader it measures 29, with a third of its pixels changing as
the field drifts.

Known cost: wlr-layer-shell exposes no occlusion signal, so it keeps rendering
behind maximised windows.

---

## Compositor changes

All in `hypr/gelo.conf`, sourced by **one line** at the bottom of
`hyprland.conf`. Delete that line to revert every compositor-side change.

- Layer blur rules for the shell namespaces. Qt cannot sample behind its own
  Wayland surface, so the frosted half of the glass material is done by the
  compositor matching `layerrule` against `WlrLayershell.namespace`.
  **Hyprland 0.56 replaced the one-line `layerrule = blur, <ns>` syntax with
  block rules** (`match:namespace`, `blur`, `ignore_alpha`); the old form errors.
- Blur tuned wider and softer for the material, plus faint noise against banding.
- `col.active_border` → accent (sanctioned accent use 2 of 3).
- Gaps and border size from tokens.
- Window animations on the same bezier as the shell.

---

## Replacements

| Was | Now | Rollback |
|---|---|---|
| Waybar | Quickshell bar | uncomment `waybar-launch` |
| wofi / hyprlauncher | Quickshell launcher | `$menu` in `hyprland.conf` |
| mako | Quickshell notifications | uncomment `exec-once = mako` |
| hyprpaper | shader wallpaper | uncomment `exec-once = hyprpaper` |
| GDM | SDDM (installed, not enabled) | `docs/login-screen.md` |

`org.freedesktop.Notifications` is a single-owner DBus name — mako and the shell
cannot both run; whichever starts first wins and the other silently does nothing.

---

## Open gaps

- **Cursor accent (3 of 3) unimplemented** — needs a generated hyprcursor theme.
- **hyprlock unverified** — see above.
- **Wallpaper shader does not stop when occluded** — no occlusion signal exists.
