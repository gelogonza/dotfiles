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


---

# Retheme — PS3 XMB

The palette, type, material language and interaction model were all replaced in
a second pass. Everything below supersedes the corresponding section above.

## Palette and type

Cold near-black blue with a single glowing cyan accent, and **no warm hue
anywhere** — the absence of orange/coral/amber is what keeps it from reading as
a generic AI-product palette. `--glow` is an 8-digit `#rrggbbaa` token; the
generator re-orders it per target because QML parses hex as `#aarrggbb` while
CSS uses `#rrggbbaa`.

Type is **Michroma**, fetched from Google Fonts into `~/.local/share/fonts` (no
sudo needed). It has exactly one weight, so hierarchy cannot come from weight —
it comes from size, opacity, tracking and glow, which is what the reference does
anyway. Note QML's font value type exposes `family` but **not** `families`, so
per-glyph fallback is fontconfig's job; the fallback chain in the tokens is
consumed by the CSS tier only.

Dropping the mono face broke the git module's Nerd Font branch glyph (U+E0A0),
which has no codepoint in a display sans and rendered as tofu. It was removed.

## Material: glass → chrome

`Glass.qml` is gone, replaced by `Chrome.qml` (brushed metal), `Glow.qml`
(selection bloom) and `Reflection.qml` (icons over water). All three are
generated into both QML roots from `design/qml/`.

All backdrop blur was removed, including the `layerrule` blocks in
`hypr/gelo.conf` — blurring these surfaces softens the hairline edges and washes
out the glow, which are the two things now carrying the material.

Caught during the build: applying `focused: true` to the launcher's Chrome panel
bloomed the entire container, which made the accent read as decoration and the
container compete with its own contents. Glow belongs on the selected *item*.

## Interaction: ripple field

`Services/Ripples.qml` is a singleton bus. The bar, launcher and notification
layer are separate Wayland surfaces that cannot draw into each other, but they
are objects in one Quickshell process, so a singleton carries interaction points
into the wallpaper's shader uniforms.

Two things that do not work the obvious way:

- **Uniform arrays.** `vec4 ripples[4]` in GLSL cannot receive data from QML —
  Qt 6's `ShaderEffect` binds uniform-block members to QML properties *by name*,
  and an array member has no matchable name. It silently never updates. The
  shader uses four discretely named slots instead.
- **Window resolution.** `item.Window.window` is null inside a Quickshell layer
  surface, because `PanelWindow` is not a plain `QQuickWindow`. The window has to
  be passed explicitly, and `mapToGlobal` does not account for a layer surface's
  margins, so the on-screen origin is derived from the window's anchors.

## Shader: noise → ribbons

The first XMB attempt reused the domain-warped fBm shader and did not look like
the reference at all — fBm is the standard "pretty background" recipe and reads
as smoke or clouds. The reference is a small number of smooth, wide, horizontal
bands of light that undulate like silk.

It is now built from explicit sine ribbons with gaussian falloff, two summed
sines per ribbon at a non-integer frequency ratio so they read as cloth rather
than as a test pattern. Measured tonal range went from a p1–p95 span of 11 levels
(bands mathematically present, visually absent) to p50=12 / p95=56.

## Reverted from the first XMB pass

The travelling blob indicator was removed in favour of pure glow, then restored
on request. It now coexists with the ripple: the element travels *and* the field
responds. `BlobIndicator.qml` was recovered from commit `27bc87d`.

## Build-order footgun, fixed

`design/build-shaders.sh` compiles the *generated* copies of the shaders. Running
it without regenerating first silently baked the previous version — so it now
invokes `build-tokens.py` itself rather than relying on anyone remembering.
