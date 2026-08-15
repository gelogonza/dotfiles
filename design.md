# Design system

The reference is the PS3 **XMB** (XrossMediaBar): a cold near-black-to-silver
blue field, one glowing blue accent, chrome surfaces, thin geometric type, and
motion that lives in a wave field *behind* the interface rather than in the
interface itself.

Everything visual in this desktop is generated from one file. If you are about
to type a colour, a duration, a font name or a pixel gap anywhere else, that is
the bug.

---

## 1. The pipeline

`design/tokens.json` is the single source of truth.
`design/build-tokens.py` fans it out to **six** targets in four languages:

| Generated | Consumer | Language |
|---|---|---|
| `quickshell/gelo/Theme/Tokens.qml` | the shell | QML |
| `sddm/themes/gelo-liquid/Theme/Tokens.qml` | login theme | QML |
| `design/tokens.css` | GTK / any web-ish surface | CSS |
| `hypr/tokens.conf` | `hyprland.conf`, `hyprlock.conf` | hyprlang |
| `ghostty/gelo-theme` | terminal | ghostty config |
| `*/Components/*.qml`, `*/Shaders/*.frag`, `*/icons/*.svg` | both QML roots | copied |

```bash
design/build-tokens.py           # regenerate everything
design/build-tokens.py --check   # non-zero if anything is stale (CI/pre-commit)
design/build-shaders.sh          # bake .frag -> .qsb  (runs build-tokens first)
design/build-cursor.py           # recolour the cursor theme
```

### Why a generator instead of one shared file

Four languages, and **two QML roots that cannot import each other**. The SDDM
theme installs to `/usr/share/sddm/themes` and runs as the unix user `sddm`;
`$HOME` is mode `700`, so the greeter physically cannot read anything under it.
Shared components, shaders and icons are therefore *copied* into each root with
their import paths rewritten, not referenced.

Generated files carry a do-not-edit banner and are committed, so a fresh clone
works without running anything. The two exceptions are documented in §9.

### Gotcha the generator now guards

A token named `on-accent` camel-cases to `onAccent`, which QML parses as a
**signal handler** for a signal called `accent` — not a property. The entire
Tokens singleton fails to load, with an error pointing at the line but never at
the cause. `camel()` now rejects any token producing an `on[A-Z]*` identifier.
The token is called `accent-ink`.

---

## 2. Typography

**Geist** (Vercel, OFL), one family for everything.

| Token | Value |
|---|---|
| `type.display` | Geist |
| `type.families` | Geist, Inter Display |
| `type.size` | 11 (caption) / 13 (body) / 15 (title) |
| `type.weight` | 300 light (default) / 400 regular (emphasis) |
| `type.trackingEm` | 0.02 |

Never 500+. Weight is not how this system builds hierarchy — size, opacity,
tracking and glow are.

**Tracking is a ratio, not a pixel count.** QML's `letterSpacing` is in pixels,
so it has to be derived from the size it is applied at: `Tokens.tracking(px)`.

### Two mechanical facts

- **QML's font value type has no `families` property**, only `family`. The
  fallback chain in the tokens is consumed by the CSS tier; in the shell,
  per-glyph fallback is fontconfig's job. It still works, just not through Qt.
- Fonts live in `~/.local/share/fonts` and need `fc-cache -f` after install.

### The Michroma detour, recorded so it is not repeated

Michroma is the literal XMB face and was tried first. It is too mannered for a
bar that is *read* constantly rather than looked at, and it ships a single
weight — which made the 300/400 weight tokens inert and forced all hierarchy
onto size and opacity. Geist is variable, so the weight axis works again.

Dropping the earlier mono face (JetBrains Mono Nerd) also broke the git module's
branch glyph: U+E0A0 is a Nerd Font private-use codepoint with no equivalent in
a display sans, and it rendered as tofu. It was removed rather than replaced.

Alternatives already installed, each a one-token change: Figtree, Inter Display,
Nimbus Sans (Helvetica clone).

---

## 3. Colour

Light/silver XMB. **Zero warm hues** — the absence of orange, coral and amber is
load-bearing; it is what keeps this from reading as a generic product palette.

### Surfaces and ink

| Token | Hex | Role |
|---|---|---|
| `bg-0` | `#eef1f8` | base surface |
| `bg-1` | `#f8fbff` | raised surface (chrome top stop) |
| `bg-2` | `#dceaf8` | hover / active |
| `border` | `#bed7eb` | hairline |
| `text-1` | `#1b4c78` | primary ink (navy) |
| `text-2` | `#5a7fb5` | secondary ink (steel) |
| `shade` | `#1f466b` | **shadows and scrims are built from this** |
| `accent` | `#3478c4` | the one accent |
| `accent-dim` | `#2e68a8` | accent at rest |
| `accent-ink` | `#ffffff` | what sits ON the accent |
| `glow` | `#4fc8ff33` | accent at low alpha |

`shade` and `accent-ink` exist because this palette is an inversion of an
earlier dark one. On a light theme, shadows can no longer derive from `bg-0` —
it is the *lightest* surface, so shadows built from it are invisible and scrims
brighten the desktop instead of dimming it.

### The wave field ramp

Kept separate from the UI surfaces so the wallpaper can be more saturated than
the chrome sitting on top of it.

| Token | Hex |
|---|---|
| `field-base` | `#7cb8e8` |
| `field-mid` | `#a8d3f2` |
| `field-high` | `#eef1f8` |
| `field-edge` | `#edf6ff` |
| `field-line` | `#e6f4ff` (filaments) |

### The accent rule

**Accent appears in exactly three places, system-wide:**

1. Active workspace indicator — `quickshell/gelo/Components/BlobIndicator.qml`
2. Focused window border — `col.active_border` in `hypr/gelo.conf`
3. The cursor — `design/build-cursor.py`

Nowhere else. Selection, hover, urgency, volume level, load thresholds and
login failure are all carried by elevation, ink colour and opacity instead.

Two sanctioned exceptions, both deliberate and both transient or semantic:

- The **ripple wavefront** in the wallpaper shader carries accent light for
  under a second before decaying.
- **Terminal ANSI 1/3/9/11** are genuinely red and yellow. They are
  load-bearing semantics — git diff, build warnings, test failures — and
  remapping them into the blue scale would break every tool that assumes them.
  They are desaturated and cool-leaning so they sit in the palette rather than
  shout out of it.

### Colour-format gotchas

Hex is stored CSS-style `#rrggbbaa`. The generator re-orders per target:

| Target | Wants |
|---|---|
| QML | `#aarrggbb` |
| CSS | `#rrggbbaa` |
| hyprlang | `rgba(rrggbbaa)` / `rgb(rrggbb)` |

---

## 4. Spacing, radius, motion

Spacing is a strict **4px grid**: 4 / 8 / 12 / 16 / 24 / 32. Bar height, blob,
password field, every gap and margin snaps to it.

Radius: 8 / 12 / 16 / 24, plus `full`. Chrome uses 8 — the XMB material is more
angular than the glass it replaced.

Motion is **one curve**, `cubic-bezier(0.22, 1, 0.36, 1)`, shared by QML
animations, Hyprland window animations and hyprlock:

| Token | ms | For |
|---|---|---|
| `fast` | 150 | hover, colour, small state |
| `base` | 250 | entrances, moves, most things |
| `slow` | 400 | ripple propagation specifically |
| `stagger` | 24 | per-row delay in the launcher |

In QML, `easing.bezierCurve` wants six values — the two control points plus the
fixed `(1,1)` endpoint. `Tokens.motion.easeBezier` is already in that shape.

---

## 5. Materials

Three components, all generated into both QML roots from `design/qml/`.

### Chrome — `Chrome.qml`

Brushed metal. A subtle vertical gradient, `bg-1` at the top fading ~6% darker
at the bottom, a 1px hairline, and a soft shadow underneath.

Enough to read as material, not enough to read as a gradient. A flat fill reads
as paint; an obvious gradient reads as 2000s web design.

**There is no backdrop blur anywhere in the shell.** The `layerrule { blur }`
blocks that used to frost these surfaces are gone — blurring them softens the
hairline and washes out the glow, which are the two things carrying the
material. Corner radius does *not* change on interaction; that was the old glass
affordance. Here the affordance is glow and the ripple it fires.

### Glow — `Glow.qml`

Selection. Nothing gets boxed when selected — it **blooms**. This is the single
most identifiable trait of the reference, and it is also how the accent budget
survives: a bloom reads as emphasis without the accent becoming a fill.

Implemented as **concentric rounded rects at quadratic falloff**. Two blur-based
approaches were tried and both failed, recorded here so they are not retried:

1. *Coloured drop shadow* — needs `brightness: -1` to suppress the copy's own
   colour, and `MultiEffect` still paints that blackened copy over the halo.
   Invisible on a dark surface, a hard black box on a light one.
2. *Colourised blur* — samples the transparent-black surround, so the halo picks
   up dark fringing. Measured `(107,128,151)` grey-blue instead of the accent
   `(52,120,196)`.

Rings cost no render target and land identically on light or dark. The trade is
that the bloom takes the content's bounding shape rather than its silhouette,
which is right for everything it wraps.

**Bloom the shape, not the artwork.** The launcher's row glow sits *behind* the
icon rather than wrapping it — blurring an app icon tints the halo with whatever
colours that icon already has, so a dark icon produced a dark glow.

### Reflection — `Reflection.qml`

The "icons floating over water" effect: a flipped, faded, gradient-masked copy
beneath the content.

Sample the **bottom** slice of the source, the part at the waterline. Sampling
from the top reflects the empty space above a glyph and produces a disconnected
fragment floating below the item. The gradient mask is not optional — without it
the mirror ends in a hard horizontal edge that reads as a rendering bug.

### Icons — `Icon.qml` + `design/icons/`

~17 hand-authored SVGs. Qt's icon-theme lookup resolves *application* icons but
returns empty for every status glyph tried, symbolic and legacy alike — Adwaita's
`index.theme` only indexes `16x16/scalable/symbolic`.

Icons are tinted by full `colorization`. **Do not add `brightness`** — it was set
to 1.0 to stop dark glyphs going muddy and blew out every already-bright source
instead; tray icons came back as pale washes.

Tray icons *are* tinted (they are frequently white and would be invisible on a
light bar). Application launcher icons are *not* — those are logos meant to be
recognised, and flattening them produces five blue smudges.

---

## 6. Shaders

One shader, `design/shaders/xmb.frag`, used by both the wallpaper and the login
screen at different speeds.

### Architecture

```
ripple displacement   →   warps uv before anything samples it
diffuse haze          →   3 broad soft masses, so the frame is not empty
filaments             →   11 strands, core + halo, thickness tapering downward
tone mapping          →   field-base → mid → high → edge, then additive light
vignette
```

**A filament is a core plus a halo**, not one gaussian:

```glsl
float bright = exp(-d2 / (core * core));   // thin bright thread
float bloom  = exp(-d2 / (halo * halo));   // wide faint glow
return bright + bloom * 0.22;
```

That split is the whole trick. A single wide gaussian produces *fog* — a smear
that is brighter in the middle. A tight core wrapped in a wide halo produces a
thread that **glows**.

Each strand is two sines at a non-integer frequency ratio (`freq` and
`freq * 1.73`), which reads as cloth rather than as a test pattern. Thickness
tapers from broad ribbons at the top to fine threads at the bottom, giving the
field a near and a far edge instead of a repeating pattern.

### Authoring a new shader

1. Write `design/shaders/<name>.frag`. Qt 6 wants `#version 440` and a
   `layout(std140, binding = 0) uniform buf { ... }` block beginning with
   `mat4 qt_Matrix; float qt_Opacity;`.
2. Add it to `SHARED_SHADERS` in `design/build-tokens.py` so it is copied into
   both QML roots.
3. Run `design/build-shaders.sh`. It regenerates first, then bakes `.frag` →
   `.qsb`. **Qt 6 will not accept raw GLSL at runtime.**
4. Bind it: `fragmentShader: Qt.resolvedUrl("root:/Shaders/<name>.frag.qsb")`,
   with one QML property per uniform, matched **by name**.

### Three hard-won rules

**Uniform arrays do not bind.** `vec4 ripples[4]` can never receive data — Qt 6
binds uniform-block members to QML properties by name, and an array member has
no name a QML property can match. It fails *silently*. Use discretely named
slots (`rippleA`, `rippleB`, …).

**Motion has to clear the quantisation floor.** The first version ran at 0.06
units/sec and measured **zero changed pixels over 30 seconds** — on a dark
palette spanning only 13–42 in 8-bit, the motion quantised away entirely and it
rendered a still image. It would have photographed as a working shader and been
a lie in motion. Measure, don't eyeball: `p50`/`p95` of the field and the
percentage of pixels that change over N seconds.

**Additive light needs different gains on light and dark.** At the dark-theme
values, the light palette clipped 10% of the frame at 250+ and washed out. A
light surface is already most of the way to white before anything is added.

### Build-order footgun (fixed)

`build-shaders.sh` compiles the *generated copies*. Running it without
regenerating first silently bakes the previous version of the shader — so it now
invokes `build-tokens.py` itself rather than relying on anyone remembering.

---

## 7. The ripple bus

Motion lives in the field behind the UI. The bar, launcher and notification
layer are separate Wayland surfaces that cannot draw into each other — but they
are objects in one Quickshell process, so `Services/Ripples.qml` carries
interaction points into the wallpaper's shader uniforms.

Two things that do not work the obvious way:

- **`item.Window.window` is null inside a Quickshell layer surface.**
  `PanelWindow` is not a plain `QQuickWindow`, so the attached property does not
  resolve. The window must be passed in explicitly.
- **`mapToGlobal` ignores a layer surface's margins.** It adds the screen offset
  but not the surface's own position, so the on-screen origin is derived from
  the window's anchors and margins instead.

The workspace blob is the one element that also moves itself — the indicator
travels *and* the field responds.

---

## 8. Cursor

`design/build-cursor.py` recolours an XCursor theme by mapping each pixel's
luminance onto a fill→outline ramp, so a black-fill/white-outline source becomes
accent-fill with antialiasing intact.

- **Pixels are patched in place** — the recolour never changes byte length, so
  the table of contents and every offset in it stay valid.
- **Un-premultiply before measuring luminance**, or semi-transparent edge pixels
  read as darker than they are and snap to the fill colour, chewing up every
  antialiased edge.
- **XCursor, not hyprcursor** — hyprcursor scales better but leaves every
  XWayland client on the system default, which is the exact inconsistency this
  removes.

---

## 9. What is *not* committed

Two generated things live outside the repo:

- **The cursor theme** (`~/.local/share/icons/gelo-cursor`) — ~12MB of binaries
  derived from Adwaita (CC-BY-SA 3.0). Shipping a recoloured copy here would
  carry the attribution obligations into this repo.
- **Fonts** (`~/.local/share/fonts`) — upstream releases, not ours to vendor.

Both are one command to reproduce. See the README.

---

## 10. Invariants

Things that will quietly break the system if changed without care:

1. **Accent stays in three places.** A fourth is a redesign, not a tweak.
2. **No warm hues** outside terminal ANSI 1/3/9/11.
3. **No backdrop blur on shell surfaces.** It kills the hairline and the glow.
4. **Everything on the 4px grid.**
5. **Never `brightness` on a tint MultiEffect.**
6. **Never a uniform array in a shader** consumed by ShaderEffect.
7. **Weight never exceeds 400.**
8. **Shadows and scrims come from `shade`**, never `bg-0`.
