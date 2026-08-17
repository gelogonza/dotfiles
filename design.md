# Design system

The reference is the PS3 **XMB** (XrossMediaBar): a cold near-black-to-silver
blue field, one glowing blue accent, chrome surfaces, thin geometric type, and
motion that lives in a wave field *behind* the interface rather than in the
interface itself.

**One sanctioned exception to that last rule:** the now-playing readout in the
bar scrolls (`material.marquee`). A track title is the only label in this system
routinely longer than the space it has, and the alternative — eliding — hides the
artist permanently rather than for a few seconds. It is a marquee because that is
the honest fix; it is not licence for anything else in the interface to move.

Everything visual in this desktop is generated from one file. If you are about
to type a colour, a duration, a font name or a pixel gap anywhere else, that is
the bug.

---

## 1. The pipeline

`design/tokens.json` is the single source of truth.
`design/build-tokens.py` fans it out to **twelve** targets in eight languages:

| Generated | Consumer | Language |
|---|---|---|
| `quickshell/gelo/Theme/Tokens.qml` | the shell | QML |
| `sddm/themes/gelo-liquid/Theme/Tokens.qml` | login theme | QML |
| `design/tokens.css` | GTK / any web-ish surface | CSS |
| `hypr/tokens.conf` | `hyprland.conf`, `hyprlock.conf` | hyprlang |
| `ghostty/gelo-theme` | terminal | ghostty config |
| `gtk-{3,4}.0/gtk.css` | GTK3 / libadwaita apps | CSS |
| `vscode/gelo-xmb/` | VS Code | theme extension (JSON) |
| `spicetify/gelo-xmb/` | Spotify | spicetify ini + CSS + JS/GLSL |
| `cava/config` | cava | cava ini |
| `design/tokens.dtcg.json` | Figma / any token pipeline | W3C DTCG |
| `design/tokens.ts` | web projects | TypeScript |
| `docs/*.html` | humans | a four-page site, published from `docs/` |
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
| `text-2` | `#466a9d` | secondary ink (steel) |
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

## 8b. GTK / libadwaita

libadwaita deliberately ignores custom GTK *themes* — its whole premise is that
apps look the same everywhere. It does read named colours from
`~/.config/gtk-4.0/gtk.css`, and overriding those is the supported way to
retheme Nautilus and every GTK file dialog.

Only the names actually needed are overridden. Overriding the full libadwaita
palette produces a theme that breaks on every release; leaving the rest at
upstream values means new widgets degrade to stock rather than to garbage.

`destructive` / `error` / `warning` / `success` reuse the terminal's ANSI red,
yellow and green. Same reasoning as §3: a delete confirmation that is not red is
a worse dialog, palette purity notwithstanding.

GTK3 reads a much smaller set of names than libadwaita, hence two generated
files. `settings.ini` stays hand-maintained — it holds preferences (dark-mode
flag, cursor size) rather than design tokens — but it must name **Adwaita** as
the theme, since that is the base whose colours the CSS overrides.

---

## 8c. The editor

`vscode/gelo-xmb/` is generated the same way everything else is. It is the one
surface that derives from the **`terminal` token block** rather than the UI
palette, so an editor split and a terminal split are the same colour and a diff
in either is the same green and red.

**It never touches `color.*`.** Where an editor needs an accent — cursor, focus
ring, active tab, badge, primary button — it uses ANSI bright blue, which is
already in the terminal palette. Reaching for `color.accent` would put the
desktop accent in a fourth place (§3) and measures worse anyway: white on
`accent` is 4.54:1, editor-background ink on bright blue is 8.13:1.

ANSI bright-black is the terminal's dim slot and measures 2.69:1 here — fine for
a shell prompt, far too quiet for comments. The theme derives three measured
steps off it toward the foreground (`dim` / `muted` / `hint`, 3.99–4.93:1), so
hierarchy comes from opacity rather than from a new hue.

Two mechanical traps, both silent:

- **`workbench.colorTheme` does nothing on this machine.** Electron reports high
  contrast, so VS Code uses `workbench.preferredHighContrastColorTheme`. Set
  both.
- **Unrecognised colour keys are ignored, not rejected.** A typo leaves that one
  surface on stock vs-dark grey. Validate key names against the shipped bundle.

## 8d. Spotify

`spicetify/gelo-xmb/color.ini`, terminal-derived for the same reason the editor
is, with ANSI bright blue where an accent is needed. One subtext step rather
than the editor's three: Spotify's lightest surface (the card) sets the worst
case at 4.83:1, and one value that clears it clears everywhere.

17 of 19 keys are live in Spotify 1.2.95. A few surfaces stay stock — notably a
~58px `#c0d62f` ring on the account avatar, the last warm chrome in the system.
**Leave them.**

`user.css` beside it carries the material language — Chrome on the player bar,
Glow on the transport, rows and cards. It is **strictly optional**: delete it
and re-apply and the `color.ini` alone is still a complete theme. Three rules
keep it that way:

1. **Colour comes from `var(--spice-*)`, never a literal**, so it inherits the
   palette and a token change needs no edit there.
2. **Visual properties only** — background, box-shadow, border, filter. Nothing
   that participates in layout, so a selector that stops matching costs an
   effect, not a broken window.
3. **Selectors are `data-testid` or Spotify's own semantic classes**
   (`.x-progressBar-fillColor`). Never a hashed styled-components class.

Two things rule 3 cost us, both correct trades:

- **Reflection has no home here.** The player bar leaves the cover art ~16px of
  clearance, so a `-webkit-box-reflect` mirror is clipped to nothing, and making
  room means touching layout. It is a bloom behind the art instead.
- **The play button stays white.** It is an Encore control with
  `colorSet="invertedLight"`, and spicetify's `replace_colors` already rewires
  that set to our palette — it was following `text` all along. The painted
  circle is a hashed class, so neither `background-color: !important` nor
  overriding Encore's colour-set variables reaches it. It is lit rather than
  repainted, which is closer to the reference anyway: the reference glows
  things, it does not tint them.

General rule that fell out of this: **for any Encore control, set the colour
set, do not fight the paint.**

`theme.js` adds the third layer: the **actual wallpaper shader**, behind
Spotify, rippling on the beat. Animating Spotify's own widgets would contradict
§7 — motion belongs in the field behind the interface, not in it. The generator
retargets `design/shaders/xmb.frag` to WebGL2 by rewriting its header only, so
there is one authored copy of the wave field and the web version cannot drift.
Unlike the wallpaper it stops when hidden, because a web page gets
`visibilitychange` and a layer surface does not.

The field sits under text, which the wallpaper never does. That is capped by a
scrim plus a brighter secondary ink scoped to the main view — the same move
`hint` makes for inputs in §8c. **If you scale `time` for this shader, divide
`rippleSpeed` by the same factor**, or wavefronts propagate that many times too
slowly and read as broken.

Beats drive the **band drift**, not ripple wavefronts. A ring expanding across
the field reads as something drawn over it rather than as the field moving, and
the reference's motion is in the ribbons. The wallpaper keeps its ripples
because an *interaction* has a point of origin and music does not — same shader,
two couplings.

It ships a live control panel (profile menu → XMB field, or Ctrl+Alt+X) for
colour source, tint strength, field brightness and saturation, main-view scrim,
UI opacity, right-panel opacity, reactivity, drift rate and turntable spin. **This is not a second source of
truth.** It invents no colours, its defaults are the
generated values, Reset returns to them, and it can copy the current settings to
the clipboard — because the point is to find a number on the live thing and then
put it in `tokens.json`.

Colour is chosen by **source** — `tokens.json` (default), a custom hex, or the
album art — with **tint strength** for how far and **cool lock** for how cool.
The choice drives the chrome as well as the field: surfaces, buttons, selection
and the waveform accent all follow it, and **Surface style** picks between
tinting the chrome and dropping it to neutral black. Because accents ride the
same luminance-preserving `tint()`, an album-coloured button keeps the contrast
a token-coloured one was measured at.
**Album tint is opt-in and hue-locked.** The field can take its colour from the
cover art (default 0), with **cool lock** compressing any hue toward the
palette's 207.5° so a red album reads as warmer without becoming warm. The rule
is a default, not a cage.

**Recolouring never changes luminance.** Hue and saturation move, then the
lightness is solved back to the original WCAG relative luminance. Holding HSL
*lightness* instead is not sufficient — it lets luminance swing 1.70× across the
hue circle, which would quietly undo the contrast work above. This is what makes
album tint safe by construction rather than by luck.

**Translucency is a decision to show whatever is underneath.** Making the main
view translucent exposed Spotify's album-art tint and turned the panel warm red
under a maroon cover — 24% warm pixels, through the one rule §3 does not bend.
Anything made translucent has to be re-checked against the palette, because
layers that were covered are now part of the design.

Read `docs/spotify.md` before running any spicetify command. `spicetify backup`
on an already-patched install destroys your way back to stock.

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
9. **Every pair the system puts together clears WCAG AA.** `build-tokens.py
   --audit` asserts it on 35 curated pairs and fails the build otherwise. This
   is not aspirational: `text-2` shipped below AA on all three light surfaces
   from the palette inversion until the audit was written and caught it.
10. **The editor and Spotify themes never read `color.*`** — both are
   terminal-derived, and the desktop accent stays in its three places.
