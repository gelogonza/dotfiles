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

## Shader: three attempts to hit the reference

1. **Domain-warped fBm.** The standard "pretty background" recipe. Reads as
   smoke or clouds — nothing like XMB. Tonal span was also 11 levels, so the
   bands were mathematically present and visually absent.
2. **A few wide sine bands.** Better structure, right tonal range
   (p50=12 / p95=56), but still wrong: a wide gaussian produces fog — a smear
   that is brighter in the middle, not a thread of light.
3. **Many thin filaments.** What actually matches: a tight bright core plus a
   much wider, much fainter halo, thirteen strands crossing over a broad
   diffuse haze. The core/halo split is the whole trick — one gaussian cannot
   make a thread that glows.

Filaments ADD to the field rather than mixing into it, which is what lets a thin
core read as brighter than whatever it crosses instead of merely differently
coloured. Final field: p50=14 / p95=35 / p99=62.

The ripple wavefront was also pulled from 0.35 to 0.16: at the higher value it
rendered as a hard cyan ring drawn over the field rather than light moving
through it, which made a sub-second transient the loudest thing on screen.

## Reverted from the first XMB pass

The travelling blob indicator was removed in favour of pure glow, then restored
on request. It now coexists with the ripple: the element travels *and* the field
responds. `BlobIndicator.qml` was recovered from commit `27bc87d`.

## Build-order footgun, fixed

`design/build-shaders.sh` compiles the *generated* copies of the shaders. Running
it without regenerating first silently baked the previous version — so it now
invokes `build-tokens.py` itself rather than relying on anyone remembering.


---

# Light XMB pass

## Palette inverted

Cold near-black → near-white silver and silk blue, navy ink, one saturated blue
accent. Two semantic tokens exist that a dark theme never needed:

- `shade` — the dark colour shadows and scrims are built from. On a light theme
  this cannot be `bg-0` any more, because `bg-0` is now the *lightest* surface;
  shadows built from it are invisible and scrims brighten instead of dim.
- `accent-ink` — what sits ON the accent (the workspace blob). Was `bg-0`;
  now white.

`field-*` is a separate ramp for the wave shader, kept apart from the UI surface
tokens so the wallpaper can stay more saturated than the chrome on top of it.

**`accent-ink` is deliberately not named `on-accent`.** That camel-cases to
`onAccent`, which QML parses as a handler for a signal named `accent` rather
than as a property — the entire Tokens singleton fails to load, and the error
points at the line without naming the cause. `build-tokens.py` now rejects any
token generating an `on[A-Z]*` identifier, with an explanation.

## Type

Michroma → **Geist**. Michroma is the literal XMB face but too mannered for a
bar that is read constantly rather than looked at. Geist is variable, so unlike
Michroma the 300/400 weight tokens actually apply again. Figtree, Inter Display
and Nimbus Sans are installed as one-token alternatives.

## Shader

Filament thickness now TAPERS from top to bottom — broad ribbons at the top of
the frame, fine threads at the bottom. Uniform thickness reads as a pattern; the
taper gives the field a near and a far edge.

Additive strength had to drop hard for the light palette: at the dark-theme
values 10% of the frame clipped at 250+ and the middle read as blown out. A
light surface is already most of the way to white before anything is added.
Final: p5=158 / p50=187 / p95=228, 0.4% clipped.

## Glow rebuilt

The bloom was a `MultiEffect` over a `ShaderEffectSource`. Both variants broke
on the light palette:

1. Coloured drop shadow — needs `brightness: -1` to suppress the copy's colour,
   and MultiEffect still paints that blackened copy over the halo. Invisible on
   dark, a hard black box on light.
2. Colourised blur — samples the transparent-black surround, so the halo picks
   up dark fringing. Measured (107,128,151) grey-blue instead of the accent
   (52,120,196).

It is now concentric rounded rects at quadratic falloff: no render target, no
fringing, identical on light or dark. The bloom takes the content's bounding
shape rather than its silhouette, which is right for everything it wraps.

Related: the launcher's row bloom sits BEHIND the icon rather than wrapping it.
Blurring app artwork tints the halo with whatever colours the icon already has —
a dark icon produced a dark glow no matter what colorization was applied.


---

# Terminal, login verification, shader pass 4

## Terminal is now a token consumer

`design/tokens.json` grew a `terminal` group, and the generator emits
`ghostty/gelo-theme`, included from `ghostty/config` via `config-file`. That
makes ghostty the **fifth** target language the token source feeds.

The previous config had a `black-orange.png` background image — warm, and
fighting a palette that forbids warm hues. Removed.

**Honest deviation, flagged in the token source:** ANSI 1/3/9/11 are genuinely
red and yellow. They are load-bearing semantics — git diff, build warnings,
test failures — and remapping them into the blue scale would break every tool
that assumes them. They are kept desaturated and cool-leaning so they sit in
the palette rather than shouting out of it.

Two tuning findings:

- At surface colour and 0.86 opacity the terminal washed out to near-white
  (measured 245,253,255) and the blur under it became invisible. Translucency
  only reads if something is left to see through. Now `#b9d5ef` at 0.68.
- Hyprland's blur `vibrancy` defaults to ~0.17 and boosts saturation of the
  blurred result, which over a blue field pulled the terminal toward cyan
  (R=228, G=B=249 — a hue shift, not a tint). Set to 0.

Compositor blur is back on, for a different reason than before: it is not for
the shell surfaces (those are layer surfaces with no blur layerrules and are
untouched), but for windows that opt in by running translucent. Right now that
is the terminal.

## Login screen verified on the light palette

Re-checked in `sddm-greeter-qt6 --test-mode` after the inversion. It renders the
XMB filament shader, the Geist clock and the chrome password field, and the
shader animates — 31.8% of pixels changing over 4 seconds. Still installed but
NOT enabled; `docs/login-screen.md` is unchanged.

## Shader pass 4

Thirteen filaments down to eleven — the lower band was dense enough that
individual threads stopped reading as threads. Drift rates ~1.35x, and the
desktop clock from 0.16 to 0.25 units/sec: at 0.16 the field read as a still
image unless you stared at it.


---

# Cursor accent, and a darker terminal

## Cursor — accent use 3 of 3

`design/build-cursor.py` recolours an existing XCursor theme to the palette:
luminance maps onto a fill..outline ramp, so Adwaita's black-fill/white-outline
cursors become accent-fill/near-white-outline with their antialiasing intact.
35 cursors and 28 aliases in about two seconds.

Three decisions worth recording:

- **Recolour, not author.** A usable theme is ~35 distinct cursors across six
  nominal sizes. Drawing them is a project, and a missing one means an app
  silently falls back to another theme mid-interaction.
- **XCursor, not hyprcursor.** hyprcursor scales better but leaves every
  XWayland client on the system default — precisely the inconsistency this was
  meant to remove.
- **Not committed.** ~12MB of binaries derived from Adwaita (CC-BY-SA 3.0);
  shipping a recoloured copy here would carry the attribution obligations into
  this repo. The script is deterministic, so running it is equivalent.

Pixels are patched in place: the recolour never changes byte length, so the
table of contents and every offset in it stay valid. Values are un-premultiplied
before luminance is measured, otherwise semi-transparent edge pixels read as
darker than they are and get pushed toward the fill colour.

## Terminal: dark, more transparent, AND higher contrast

Asked for both more transparency and better contrast, which on a light desktop
normally trade against each other — every point of opacity given up lets more
bright field through and lifts the effective background.

Measured, in order:

| | rendered background | contrast |
|---|---|---|
| light bg `#b9d5ef` @ 0.68 | — | washed, blur invisible |
| dark bg `#14293f` @ 0.62 | (68,105,138) | 4.71:1 — AA only |
| + blur `brightness = 0.45` | (39,64,89) | **8.71:1 — AAA** |

The lever that resolves the conflict is Hyprland's `decoration:blur:brightness`,
which darkens the blurred backdrop seen *through* translucent windows. That buys
contrast without buying it back in opacity, so the terminal ends up more
transparent than it started AND clears AAA.

Light-on-dark also degrades better here: bleed-through from a bright desktop can
only lighten the background, which helps light text and hurts dark text.

The ANSI palette was rebuilt for a dark background — the previous set was tuned
for light and colours 0-7 would have been unreadable.
