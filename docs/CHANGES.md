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


---

# VS Code — the editor joins the token system

Roadmap 1.1. `design/tokens.json` now feeds a **sixth** target: a theme
extension in `vscode/gelo-xmb/`, generated by `render_vscode()`.

The theme derives from the **`terminal` token block**, not the UI palette, so an
editor split and a terminal split side by side are the same colour and a diff in
either is the same green and red. Rule this establishes: *surfaces you work in
are dark, chrome you work with is light.*

## The reason it had never worked

The theme had been generated for a while and looked correct on disk. Installing
it and setting `workbench.colorTheme` changed nothing, and the failure is
silent — no error, no notification, the setting simply has no effect.

**Something in this session reports high contrast to Electron.** When
`nativeTheme.shouldUseHighContrastColors` is true, VS Code ignores
`workbench.colorTheme` entirely and uses
`workbench.preferredHighContrastColorTheme` instead. On a fresh profile it fills
that key in with **Solarized Dark** and runs it.

That is why the earlier settings.json carried
`"workbench.preferredHighContrastColorTheme": "Halcyon"` alongside the normal
key — the same trap, worked around once already without the cause being written
down. **Both keys must be set**, and this applies to any future editor theme.

Diagnosing it took longer than it should have because the symptom looks like a
broken theme file. What settled it was reading VS Code's own cached state:

```bash
python3 -c "import sqlite3,json;print(json.loads(dict(sqlite3.connect(
  '$HOME/.config/Code/User/globalStorage/state.vscdb').execute(
  \"select key,value from ItemTable where key='colorThemeData'\"))['colorThemeData'])['label'])"
```

It printed `Solarized Dark` while the settings said otherwise, which named the
problem immediately. A probe — setting `editor.background` to `#ff0000` and
seeing the window stay Solarized teal — had already proved the file was not
being read, but not why.

## What verification then found

With the theme actually rendering, three real defects showed up:

- **Comments measured 2.69:1.** They were ANSI bright-black, which is right for
  a shell prompt and much too quiet for the text you read for eight hours. The
  dim ramp is now three measured steps off that slot toward the foreground:
  `dim` 3.99:1 (line numbers), `muted` 4.93:1 (comments, inactive tabs,
  descriptions), `hint` 4.83:1 on the lighter input surface (placeholders).
  Hierarchy by opacity, which is what design.md §2 asks for. Worst syntax scope
  is now 4.77:1; every one clears AA.
- **Unset keys fall back to stock vs-dark grey.** Measured at 1.7% of a window —
  small, but it was a `#3c3c3c` input box in a navy frame, which reads as
  unfinished more than a wrong blue would. Coverage went 70 → 277 keys, grouped
  by surface so gaps are visible in the source. Widgets (palette, suggest,
  hover, peek), inputs, dropdowns, menus, notifications, diffs, the git gutter
  and the minimap were all missing.
- **The theme reached into `color.accent`** for buttons, badges, focus ring and
  the active tab — six uses of the desktop accent, which design.md §3 caps at
  three system-wide, in a file whose own docstring says it does not use the UI
  palette. All of them are now ANSI bright blue, which is already in this
  palette. It also measures better: white on the desktop accent is 4.54:1,
  editor-background ink on bright blue is 8.13:1.

## Validate key names, not just colours

**VS Code silently ignores unrecognised colour keys.** A typo is not an error —
it is one surface that stays stock grey forever. Two invalid keys were caught
this way (`peekViewResult.foreground`, `pickerGroup.background`; neither
exists), by checking every key against the shipped registry:

```bash
grep -F '"peekViewResult.foreground"' \
  /usr/share/code/resources/app/out/vs/workbench/workbench.desktop.main.js
```

Extension-contributed keys (`gitDecoration.*`) live in
`resources/app/extensions/*/package.json`, not the workbench bundle — check both
before concluding a key is fake. All 277 keys now validate.

## Installed

`~/.vscode/extensions/gelo-xmb` is a **symlink** into the repo, so regenerating
updates the installed theme in place; only a window reload is needed. The
extension itself is committed — unlike the cursor theme, it is a few KB of
generated JSON with no upstream licence attached.


---

# Spotify — spicetify, and the limits of theming an app you don't control

Roadmap 1.3. A **seventh** target: `spicetify/gelo-xmb/color.ini`, generated by
`render_spicetify()`. Spotify was running **StarryNight / orange** — the last
warm hue anywhere in the system, and a direct contradiction of §3.

Dark and terminal-derived, on the same reasoning as the editor: Spotify is a
full application window sitting next to the terminal and the editor, and all
three being one colour is the point. Accent is ANSI bright blue, not
`color.accent` — the desktop accent stays in its three places.

One subtext value rather than the editor's three-step ramp. Spotify puts
secondary text on three surfaces and the card is the lightest, so that worst
case sets the step: the editor's `muted` is only 4.12:1 on a card, so this uses
the brighter one — 5.78 main / 6.80 sidebar / 4.83 card.

## Colours first

The first pass was `color.ini` only — no stylesheet — on the grounds that
spicetify modifies the Spotify **install**, so every CSS rule can break on an
update. A `color.ini` only feeds spicetify's `--spice-*` variables, the
narrowest and most stable part of the contract. A stylesheet was added
afterwards (see the next section); the split is deliberate and the `color.ini`
remains a complete theme on its own.

**17 of the 19 keys are live.** Checked the same way the VS Code keys were —
against what the app actually consumes:

```bash
grep -ohE "var\(--spice-[a-z-]+" /opt/spotify/Apps/xpui/*.css | sort | uniq -c | sort -rn
```

`sidebar-alt` and `selected-row` are standard spicetify keys that Spotify
1.2.95 does not reference at all. Kept — they cost nothing and Spotify moves
these between releases — but they are doing nothing today.

## Two things that look like bugs and are not

**The play button and progress fill are white, not accent.** That is
`--spice-text`; modern Spotify does not put its accent there. The result is a
Spotify with almost no accent in it, which is the correct outcome for this
system rather than a failure to theme.

**The progress trough measures `#56606a`, which looks like a stock grey.** It is
not — it is `rgba(255,255,255,0.30)` over our `player` colour. Predicted
`#565f69` against a measured `#56606a`, so it is theme-derived and moves with
the palette. Worth recording because the instinct on seeing a neutral grey in a
navy UI is to go hunting for a missing key, and there isn't one.

## What stays stock

The account avatar carries a hardcoded `#c0d62f` ring — about 58 pixels, not
routed through `--spice-*`, and the only warm chrome left in the system.
Measured warm pixels: **0.00%** of the player bar, 0.75% of the top bar (that
ring), 1.75% of the sidebar (playlist cover artwork, which is content and
correctly untouched).

It stays. Fixing ~58px would mean adding a stylesheet against generated class
names, which is exactly the maintenance burden the colours-only decision exists
to avoid. The rule this sets: **a slightly wrong surface beats a stylesheet
pinned to a moving target.**

## The trap that is worth more than the theme

`spicetify backup` and `spicetify backup apply` back up whatever is in
`/opt/spotify` **at that moment**. Run either while Spotify is already patched
and the backup becomes a copy of the patched client — `spicetify restore` can
then never return you to stock, and the only way back is reinstalling the
package.

Since the install here was already patched, the correct command was plain
`spicetify apply`. Pre-flight was: backup version (`[Backup]` in
`config-xpui.ini`) matches `pacman -Q spotify`, `xpui.spa` passes a zip
integrity check at 544 entries, and `/opt/spotify/Apps/xpui/` exists — which is
itself the tell that the install is already patched.

A `pacman -Syu` that upgrades Spotify wipes the patch and invalidates the
backup. That is the one moment `backup apply` is right. Full procedure,
including recovery from a stale backup, in `docs/spotify.md`.

Note also that spicetify requires `/opt/spotify` to be mode `777`, so any local
user can modify the Spotify client. That is a real trade and it is made
knowingly; it is a spicetify requirement, not a choice this repo makes.


---

# Spotify, second pass — the material language

The colours were right and the result was flat: three navy tiers and white
text, none of the chrome/glow/reflection that carries the system everywhere
else. `render_spicetify_css()` adds `spicetify/gelo-xmb/user.css`.

**It is designed to be thrown away.** The `color.ini` is still the theme; the
stylesheet is an enhancement that can be deleted and re-applied at any time.
Three rules keep it cheap to lose: colour only ever from `var(--spice-*)`,
visual properties only (nothing touching layout), and selectors restricted to
`data-testid` or Spotify's own semantic class names — never a hashed
styled-components class.

What landed, measured:

- **Chrome on the player bar.** `#14212f` at the top to `#0c1926` at the
  bottom, plus a hairline and an upward shadow. Present without reading as a
  gradient, which is the whole brief for that material.
- **Glow on the transport.** Progress and volume fills are the accent with a
  three-stop box-shadow approximating the quadratic falloff `Glow.qml` draws.
  Around the play button the bloom lifts the chrome from `#111f2c` to `#1d303f`
  at the edge and decays over ~12px.
- Hover blooms on library rows, tracklist rows and cards; hairlines on cards.

## Two things that did not work, and what replaced them

**Reflection has no home in Spotify.** `Reflection.qml`'s mirror was the
obvious win — "icons floating over water" is the signature. The player bar
leaves the cover art about **16px** of clearance before the window edge, so
`-webkit-box-reflect` is clipped to nothing. Making room means changing layout,
which is the one thing this stylesheet does not do. Replaced with a bloom
behind the art: same "floating, not pasted on" read, needs no space, grows into
the chrome instead of below it.

**The play button cannot be recoloured, and should not be.** It looked unthemed
and was not: it is an Encore control with `colorSet="invertedLight"`, and
spicetify's `replace_colors` has *already* rewired that colour set to our
palette — `--background-base: var(--spice-text)`. It was following the theme
via `text`, which is white, because Spotify deliberately inverts its primary
transport control.

Two attempts to force it accent, both failed and both instructive:

1. `background-color: var(--spice-button) !important` — the cascade is fine
   (`user.css` is injected after `xpui-snapshot.css`), but the painted circle
   is a hashed styled-components class, not the element carrying the testid.
2. Overriding Encore's colour-set variables on the button — same reason.

Reaching the real element means selecting on `.eWU4JoxyECcwnSf_`-style hashes,
which is exactly the fragility rule 3 exists to prevent. So the button is **lit
rather than repainted**, which is closer to the reference regardless: the
reference glows things, it does not tint them.

The general rule, worth more than the button: **for any Encore control, set the
colour set, do not fight the paint.** The sets are readable directly:

```bash
grep -o '\.encore-inverted-light-set[^{]*{[^}]*}' /opt/spotify/Apps/xpui/xpui-snapshot.css
```

## A verification note

Two of these were called "working" off a rendered screenshot before being
measured, and one of them — the accent play button — was simply wrong; the
button was `#dfe9f4` in the screenshot that supposedly showed it blue. On a
small circular control at 1266px wide, a bright bloom around white reads as a
tinted disc.

`grim` plus a pixel probe settles it in seconds and the eye does not. Same
lesson as the shader that rendered zero changed pixels: **screenshot and
measure, do not look.**


---

# Spotify, third pass — the wave field, on the beat

The static theme was right and still inert. Animating Spotify's own widgets
would have contradicted the system: motion here lives in a field *behind* the
interface, not in the interface (design.md §7). So Spotify gets the **actual
wallpaper shader** behind it, and the four ripple slots that carry interaction
points on the desktop carry **beats**.

`render_spicetify_js()` emits `spicetify/gelo-xmb/theme.js`. Three layers now,
each deletable from the top down:

| File | Is | If deleted |
|---|---|---|
| `color.ini` | the theme | nothing works |
| `user.css` | the material — chrome, glow | static flat theme |
| `theme.js` | the motion — field, ripples | static material theme |

`theme.js` injects its own transparency and scrim CSS, so deleting it removes
the hole and the thing filling it together. Nothing in `user.css` depends on it.

## One shader, retargeted rather than reimplemented

`_glsl_es()` rewrites `design/shaders/xmb.frag` from Qt 6 GLSL to WebGL2
(GLSL ES 3.00) — **header only**, so there is still exactly one authored copy of
the wave field and the web version cannot drift from the wallpaper's. It swaps
`#version 440` for `#version 300 es` plus a precision qualifier, unpacks the
`layout(std140) uniform buf` block into loose uniforms, drops the
`layout(location=…)` qualifiers ES will not take on varyings, and redeclares
`qt_Opacity` as a constant so the body's final multiply still compiles untouched.
Validated with `glslangValidator` before it ever reaches Spotify.

It also does something the desktop cannot: **stop when hidden.** The roadmap
lists "the wallpaper shader does not stop when occluded" as a permanent gap
because wlr-layer-shell exposes no occlusion signal. A web page gets
`visibilitychange` for free.

## The ripple clock bug

Ripples fired and appeared not to. Measured frame-to-frame over 0.4s intervals:
**0.00%, five times running**, while a 4s interval showed 6.9% — a field
drifting but nothing propagating.

`material.ripple.speed` is units per **real** second, but the shader derives a
wavefront's radius as `age * rippleSpeed` on the same clock it uses for drift —
and that clock arrives pre-scaled by the caller's rate. At `RATE = 0.16` the
wavefront expanded six times too slowly: about **eleven seconds** to cross the
window. Passing `speed / RATE` fixes it; 0.4s intervals now measure ~1.2%.

Worth knowing for any future consumer of this shader: **if you scale `time`, you
must divide `rippleSpeed` by the same factor.** The `age > 2.5` cutoff and the
`exp(-age * 1.6)` decay are on that clock too, so a ripple also lives 1/RATE
times longer than the token implies — harmless here, because four slots
round-robin on every beat and overwrite each other long before that.

Beats come from `Spicetify.getAudioData()`, filtered to `confidence > 0.4`.
Analysis is missing for local files and most podcasts, so there is a slow pulse
fallback and a ripple on track change; every failure path degrades to fewer
ripples, never to a broken field.

## Text on a moving background

The field sits under content, which the wallpaper never does, and that is the
whole difficulty. The clean way to measure it is to **isolate the field by
motion** — the pixels that differ between two frames are the field, since
nothing else in the window animates. Colour filtering cannot separate it from
album artwork; motion can.

Measured that way, at the first brightness tried, the field's top 5% put
secondary text at **4.17:1** — under AA, and a regression on the flat 5.78:1 it
replaced. Primary text was never at risk. Three levers, applied in order:

1. **A dimmer ramp** than `field-*`, derived from the terminal block. The
   wallpaper's ramp behind a dark Spotify would be a lightbox.
2. **A scrim**, `rgba(main, 0.68)`, rather than full transparency. This is the
   right instrument: it caps the bright tail without touching the type
   hierarchy, and it drops the diffuse haze while leaving the filament cores
   legible — the correct emphasis anyway, since the threads are what make this
   read as XMB.
3. **A brighter secondary ink scoped to the main view** (`#a5b7cc`), exactly the
   move `hint` makes for inputs in the editor theme: a lighter surface gets its
   own step rather than the surface being darkened until the existing step fits.
   3.80:1 → 4.75:1 against the filament cores, with the luminance gap below
   primary text preserved, and no leak — sidebar and player keep standard
   subtext.

Final: primary text 6.2:1 at p99 of the field, secondary 5.0:1 at p95. The
brightest ~1% still runs under AA for secondary text; the knobs are the scrim
alpha and `colorLine`, both one line in `render_spicetify_js()`.

## Measurement note, again

Two effects were called working off a rendered screenshot in the previous pass
and one was wrong. This pass, the ripples looked fine in a still and were
crawling at a sixth speed — invisible to the eye, obvious the moment two frames
0.4s apart were differenced. **Short-interval differencing is the test for
propagation; long-interval is the test for drift.** They catch different lies.


---

# Spotify, fourth pass — a control panel, and what transparency exposed

The right panel is translucent now (`--gelo-panel`, default 0.88), but the
larger change is that the values worth arguing about are adjustable live:
a panel in Spotify with sliders for field brightness, scrim, right-panel
opacity, beat reactivity and drift rate, plus an on/off. Profile menu →
**XMB field**, or **Ctrl+Alt+X**. Settings persist in Spotify's LocalStorage.

## On having a settings panel at all

`tokens.json` is still the single source of truth, and the panel is careful not
to become a second one. It invents no colours — it scales values that are
already parameters, its defaults *are* the generated values, and Reset returns
to them exactly. Its real job is the one a design engineer actually needs: find
the number by eye on the live thing, then move it into the token source. Hence
the **Copy** button, which puts the current settings on the clipboard, and the
line of text under it saying where they belong.

CSS-side settings go through custom properties (`--gelo-scrim`, `--gelo-panel`)
so a slider sets one variable rather than rewriting rules; GL-side settings are
uniforms. The panel is plain DOM rather than `PopupModal` — this layer has to
survive Spotify updates, and every API it touches is a way to not.

Time is now **accumulated** rather than derived as `elapsed * rate`, so moving
the rate slider changes speed from that moment instead of jumping the clock and
teleporting every live ripple. `rippleSpeed` is re-divided by the new rate on
every change, for the reason in the previous section.

## The menu item that registered into nothing

`Spicetify.Menu` is not populated when `theme.js` first runs, so a single
`new Spicetify.Menu.Item(...).register()` at boot registers nothing — and
because the call was wrapped in a `try/catch`, it failed **silently**. The
symptom was an empty result: every other spicetify entry ("Experimental
features", "Home config") sat in the profile menu and ours did not, with no
error anywhere. It now retries every 300ms until it takes, and gives up after
~30s. Verified by opening the menu and reading it, which is the only way this
particular failure is visible at all.

Worth generalising: **a `try/catch` around an initialisation call converts a
race into a silent absence.** If the thing being registered is user-visible,
check that it appeared rather than that the call did not throw.

## Two things that only showed up once it was translucent

**Ctrl+Shift+X is Spotify's Connect panel.** Binding it opened both at once —
visible immediately in a screenshot, invisible in the code. Moved to Ctrl+Alt+X.
The profile-menu item is the real entry point; the shortcut is a convenience.

**Making the main view translucent exposed Spotify's album-art tint.** A maroon
album cover turned the entire middle panel warm red — straight through the one
rule this palette does not bend. It had always been there; the opaque surface
above it was the only reason it never showed.

Measured warm pixels in the main view: **24.35% before, 1.68% after**, and the
1.68% is album artwork, which is content and correctly untouched.

The tint arrives as `--background-base`, painted by
`.main-actionBarBackground-background`'s gradient. Killing that layer inside the
main view and neutralising the `--background-tinted-*` set fixes it — the same
"set the colour set, do not fight the paint" lever as the Encore button.

The general lesson is worth more than the fix: **transparency is not only a
visual change, it is a decision to show whatever was underneath.** Anything
made translucent needs re-checking against the palette rules, because layers
that were previously covered are now part of the design.


---

# Spotify, fifth pass — colour controls, album tint, turntable

Three things: colour in the panel, the right-panel cover art as a spinning
record, and the field taking its hue from the album — which is the thing the
previous pass deliberately *removed*.

## Album tint, and how it stays inside the system

Last pass neutralised Spotify's album-art tint because a maroon cover turned the
main view warm red, through the one rule §3 does not bend. Reintroducing it on
purpose needed a way to be both things at once, so there are two controls:

- **Album tint** (0..1, default **0**) — how much of the cover's hue the field
  takes. Off by default: the system's answer is still "no".
- **Cool lock** (default **on**) — compresses any hue toward the palette's own
  207.5°, keeping ~±25°. A red album reads as *warmer*, never as warm.

The palette rule is now a default rather than a cage, which is the honest
version of it for a desktop that is also a portfolio piece.

## The part that matters more than the feature

**Recolouring cannot be allowed to change how bright the field is**, or the
contrast work in §8d silently comes undone the first time a yellow album plays.

The obvious approach — rotate hue in HSL, hold lightness — is wrong, and not by
a little. HSL lightness is not perceptual brightness. Measured on the field's
brightest colour at constant `L`:

| | relative luminance |
|---|---|
| token hue (207°) | 0.2325 |
| min, at 240° | 0.1206 |
| max, at 60° | 0.3942 |

**a 1.70× swing**, and still 1.46× inside the cool-lock band. That is more than
enough to push secondary text under AA.

So `tint()` rotates hue and scales saturation, then **solves for the lightness
that reproduces the original WCAG relative luminance** — a 24-step bisection,
which is exact enough and runs on slider moves rather than per frame. Verified
by driving the shipped helpers directly over every hue at four saturations:

```
max relative-luminance error: 0.000%
```

Contrast therefore holds for any album and any slider position, by construction
rather than by luck.

## Turntable

The right-panel cover art becomes a circle with groove rings, rotating on a
14s period (adjustable), `animation-play-state` following playback so it stops
when the music does. Measured: 87.7% of the disc's annulus changes over 3s,
against ~0 for a still image.

**Styled on the image, never the container.** The first attempt put
`position` / `overflow` / `border-radius` and an `::after` on
`.main-nowPlayingView-coverArt` and the artwork vanished outright — the slot
measured as panel background with none of the cover in it. Spotify sizes that
container itself, and touching its box model is a way to lose the contents. An
`<img>` cannot affect layout, so the image-level version cannot break anything;
grooves are a stack of inset ring shadows because an `<img>` has no
pseudo-element.

## A verification note

Midway through, the art slot went blank and the obvious reading was "the CSS
broke it again" — but the panel had flipped into **video** mode, from one of the
synthetic clicks used to test the menu. The tell was in the frame the whole
time: the button said *Switch to video*, so audio mode was still active in the
capture that actually mattered. Two different failures wearing the same
appearance, a few minutes apart.

Read the whole frame before concluding, not the region under suspicion.


---

# Spotify, sixth pass — UI opacity, colour sources, waveform bar

## Colour is now a source, not a slider

The panel asks **where colour comes from** rather than how much to nudge it:

| Source | |
|---|---|
| **tokens.json** | the default — the system's palette, unchanged |
| **Custom** | a native colour picker and a hex field, kept in sync |
| **Album art** | read off the current cover |

**Tint strength** says how far toward that source the field goes; **cool lock**
compresses the result toward the palette's 207.5°. The default is still
tokens.json, so nothing about the system's colour changes unless asked.

Everything still routes through the luminance-preserving `tint()` from the last
pass, so no source and no slider position can alter the field's brightness — the
contrast work in §8d survives a hot pink album by construction.

## UI opacity

One alpha opens every remaining opaque surface onto the field, rebuilt from the
`--spice-rgb-*` triplets spicetify already emits:

```css
--spice-sidebar: rgba(var(--spice-rgb-sidebar), var(--gelo-ui));
```

Sidebar, top bar, player bar, cards and elevated surfaces, in one variable. The
main view keeps its own scrim and the right panel its own alpha, because those
two sit over the field differently and wanted separate control.

## The waveform bar

The player bar is now the track's own loudness envelope, drawn from the same
`segments[].loudness_max` the beats come from, filling as it plays.

It is painted as **background layers on a bar that is already ~80px tall**, so
there is room for a real waveform and nothing about the layout changes — the
alternative, growing the 4px progress bar, is a layout edit on a container
Spotify owns, and the turntable already demonstrated how that ends. The hot
layer is **pre-clipped to the playhead when generated**, because CSS cannot clip
a background and scaling one would squash the waveform rather than reveal it.
Regenerated a few times a second, not per frame: `toDataURL` is far too
expensive at 60Hz and half a second of playhead precision is invisible.

## Making the album read actually reliable

Reading the cover does not depend on Spotify internals. Its image CDN answers
with `access-control-allow-origin: *` — verified directly:

```bash
curl -sI -H "Origin: https://xpui.app.spotify.com" \
  https://image-cdn-fa.spotifycdn.com/image/<id> | grep -i access-control
```

so an anonymous `<img>` can be drawn to a canvas and sampled. Hue is averaged as
a unit vector weighted by saturation squared, so a mostly-grey cover with one
saturated element still resolves and hues near 0/360 do not average to the
opposite side of the circle. The Spicetify extractors are tried first as a
nicety; this is the guarantee.

**Extraction now watches the artwork, not the track change.** Firing on track
change and retrying on a fixed schedule is a race — the DOM swaps the cover a
beat or two later, and when the retries ran out first the read silently produced
nothing. Polling the cover URL every 600ms self-heals for late loads, video
mode, and covers arriving out of order.

## Two bugs, and the same lesson twice

**The panel disagreed with itself.** The colour swatch showed a magenta taken
from the *previous* cover while "Detected" correctly said nothing had been read
for the current one. Cause: track change blanked `ALBUM` but never re-applied
the uniforms, so the field kept a stale colour while the live readout reported
the truth. `ALBUM` is no longer blanked speculatively — it changes only when a
new colour is actually read.

**The readout that could never work.** "Detected" sat empty regardless, and it
read exactly like broken colour extraction. It was not: the poll starts inside
`buildPanel()`, which runs *before* the node is appended, so its own
`document.body.contains(wrap)` guard failed on the first tick and it never
rescheduled. Deferring the first tick by one turn fixes it.

Both were diagnosed by **two indicators of the same fact disagreeing** — which
is worth more than either indicator alone, and is the argument for putting the
detected colour on screen rather than trusting that extraction "probably ran".


---

# Spotify, seventh pass — UI opacity that actually covers the UI

## Half the chrome does not read `--spice-*`

The first UI-opacity pass rebuilt the spice surface variables as rgba and left
the left panel, the top bar and the home interior stubbornly solid. They do not
paint `--spice-*` at all:

| Surface | paints |
|---|---|
| left panel, home interior | `--background-base` |
| top bar | `--background-elevated-base` |
| player bar, cards | `--spice-player` / `--spice-card` |

So Encore's background variables are alpha'd at `:root` too, and the whole shell
now opens together. A side effect worth having: this permanently kills Spotify's
album-art tint, which arrived through `--background-base` — the surgical fix
from the fourth pass is now redundant, though it stays as belt and braces.

**UI opacity is the master.** The main-view scrim and the right-panel alpha
multiply on top of it rather than sitting beside it, so one slider opens
everything and the other two remain available to hold content back where text
legibility needs it.

## The waveform belongs on the playback bar

It was spanning the whole player bar as a background, which is not what a
waveform is for. It now replaces the progress strip itself.

Two things made that safe:

- **Height comes from `--progress-bar-height`**, which Spotify already drives
  the bar from — asking for room through the app's own variable rather than
  editing a box model. The same lesson as the Encore colour sets and the
  turntable, for the third time: set the variable, do not fight the layout.
  It is declared on `.progress-bar` itself, so that is what must be overridden;
  setting it on an ancestor silently does nothing, which cost one cycle.
- **Both layers paint on `.x-progressBar-progressBarBg`**, which is static and
  full width. The fill element cannot carry the played half — it is a
  full-width element moved with `transform: translateX`, so a background on it
  would slide across rather than be revealed. The hot layer is pre-clipped to
  the playhead when generated instead.

## The bar that disappeared

Making the background and fill transparent so the waveform could show through
also made the progress bar **invisible on any track without audio analysis** —
local files, most podcasts, and anything where the call fails. Measured as a
thin dead line where the bar used to be.

Everything waveform-related is now gated behind a `gelo-has-wave` class set only
when segments actually exist, so a track without analysis gets Spotify's normal
progress bar back. The general shape of the mistake: **an enhancement that
removes the thing it replaces has to check that the replacement arrived.**


---

# Spotify, eighth pass — why `:root` was not enough

The now-playing panel's inner boxes — cover art, About the artist, Credits,
queue — stayed solid at low UI opacity while the panel around them opened up.

**A CSS custom property resolves to the nearest ancestor that declares it**, and
`.encore-dark-theme` re-declares these much closer to the element than `:root`
does:

```
.encore-dark-theme { --background-elevated-base: #1f1f1f }
```

Every `:root` override in the previous pass lost that race for any subtree under
a theme class, which is most of the app. The variables are now set on
`.encore-dark-theme` / `.encore-light-theme` as well, so the whole subtree
inherits the alpha.

Only the neutral surface values are touched. Encore declares the same property
names inside narrower selectors for alerts and inverted controls; those are more
specific and still win, which is what should happen — a red alert should stay
red.

The panel's own boxes are also painted directly
(`.main-nowPlayingView-section`, `-mainWrapper`, `-coverArtContainer`,
`-aboutArtist`, `-credits`) rather than relying on variable resolution alone, so
they follow UI opacity regardless of what Spotify resolves those variables to
next release. `-mainWrapper` needed it most: it lays a near-opaque black
gradient over the panel, which reads as a dark slab the moment anything behind
it is supposed to show.

## The generalisable bit

Three passes in a row now have come down to the same thing, and it is worth
stating once:

> **Set the variable, do not fight the paint — but set it where the element will
> actually look.**

`:root` is the right instinct and the wrong scope whenever the app defines a
design-system class between the root and the element. When an override appears
to do nothing, the question is not "is my selector more specific" but "which
ancestor declares this property closest to the target".


---

# Spotify, ninth pass — the UI follows the colour source

Picking "Album art" now recolours the chrome as well as the field: surfaces,
buttons, selection, notifications and the waveform accent all move with the
cover. A **Surface style** control chooses what the chrome does with it:

- **Tinted** — surfaces take the album hue through the same pipeline as the
  field.
- **Neutral black** — surfaces drop to plain black at the UI alpha, so the
  album shows through without colouring the furniture.

The surface ramp (`main` / `deep` / `raised`) is derived in JS and published as
`--gelo-surf-*` triplets, so every rule that used to hardcode the token navy now
reads whichever colour is in force. Accents publish as `--gelo-accent` and
`--gelo-accent-rgb`, which `--spice-button`, `--spice-button-active`,
`--spice-selected-row`, `--spice-notification` and `--spice-rgb-button` all
point at.

**Album-coloured buttons cannot become unreadable buttons.** Accents ride the
same luminance-preserving `tint()` as the field, so however far a cover drags
the hue, dark ink on a button keeps the contrast it was measured at. This is the
third feature that has come for free from that one decision.

## The override that was never applying

The field went red and the UI stayed blue. Measured: panel accents at hue 207°
while the detected album colour was hue 9°.

`theme.js` appends its `<style>` to `document.head`. Spicetify injects
`colors.css` and `user.css` as `<link>`s at the **top of `<body>`** — which is
*later* in document order. Both declare `--spice-button` at `:root`, both at
specificity (0,1,0), so the later one wins and every `--spice-*` override in the
injected stylesheet was silently losing.

The field was unaffected because it is WebGL uniforms, not CSS — which is
exactly why the two halves disagreed, and the disagreement is what made the bug
visible at all.

Fixed by raising the selector to `html:root`, specificity (0,1,1), which wins
regardless of document order. Preferred over moving the `<style>` into `<body>`,
because the ordering is spicetify's to change and specificity is not.

Worth keeping: **when a `:root` custom-property override does nothing, check
what else declares it at `:root` and which comes later.** Between this and the
`.encore-dark-theme` finding two passes ago, both failures were the same
question asked at different scopes — *who declares this property closest, and
last?*


---

# Spotify, tenth pass — the last blue box, and neutral chrome

## The box that stayed navy

With the whole panel tinted red, the "Related music videos" section was still
token blue. Overriding `--spice-sidebar` / `--spice-player` / `--spice-card` was
not enough: nothing had touched **`--spice-main`**, or any of the
**`--spice-rgb-*` triplets**. Anything painting `var(--spice-main)` directly, or
rebuilding a colour with `rgba(var(--spice-rgb-card), a)`, kept the original
navy.

Both are now redirected at `html:root`, the triplets pointing straight at
`--gelo-surf-*`. Worth remembering that spicetify exposes each surface **twice**
— as a colour and as a triplet — and overriding one does not touch the other.

## Chrome goes neutral once colour leaves the tokens

In `tokens.json` mode nothing changes. In **Custom** or **Album art** mode the
buttons, the hex input, the sliders and the waveform all go **white**.

A tinted button on a tinted surface is two things competing for the same hue and
both losing. White reads on any of them, so the colour stays where it is doing
work — the field — and the controls get out of its way. Measured on the player
bar: the waveform now sits at saturation 0.07 over a red bar.

## The panel that dimmed itself out of usefulness

The control panel drew its background from `--spice-player`, which follows UI
opacity — so at 0.30 the panel itself was 30% opaque and barely readable. **A
settings panel you cannot read at low UI opacity is a settings panel you cannot
use to raise UI opacity.**

It now reads `--gelo-surf-*` so it still follows the palette, but deliberately
not `--gelo-ui`. General shape: a control surface must not be governed by the
setting it controls.


---

# Spotify, eleventh pass — the home shortcuts strip

The row with **All / Music / Podcasts / Audiobooks** and the playlist tiles
under it kept its own indigo gradient while everything around it followed the
palette, and it changed hue when a tile was hovered.

It paints an art-derived gradient through **`--background-image`**, on a hashed
styled-components class. Two decisions:

- **Neutralise the variable, not the class.** `.rFRM_ac94qAgSEIf` is exactly the
  kind of selector that evaporates on a Tuesday. `--background-image: none` at
  `html:root` kills the image layer wherever it is used, and what remains
  underneath is a gradient to `--spice-main`, which already follows the colour
  source.
- **`!important` is required here**, unusually. Spotify sets this property
  **inline** on the hovered item, and an inline declaration beats a stylesheet
  one without it. That is also what made the strip change colour on hover, so
  the same character fixes both.

Semantic backups (`.main-home-homeHeader`, `.main-home-filterChips*`) are
painted transparent as well, so this does not depend on the hashed element
keeping its shape.

## The running theme, stated once more

Every one of the last five fixes has been the same question in a different
place: **which declaration wins for this property, and why?**

| Symptom | Answer |
|---|---|
| button colour ignored | Encore colour-set variables, not `background-color` |
| progress bar height ignored | the variable is declared on `.progress-bar` itself |
| panel boxes stayed solid | `.encore-dark-theme` declares it closer than `:root` |
| UI ignored the album | `colors.css` declares it at `:root` *later* |
| shortcuts strip stayed indigo | Spotify declares it **inline**, per hover |

Specificity, proximity, order, inline. Four different ways to lose the same
argument, and none of them are "your selector was wrong".


---

# Spotify, twelfth pass — the bands move, not the rings

The ripple wavefronts are gone. Beats now surge the **band drift** instead.

Concentric rings expanding across the field read as something drawn *over* the
wave field rather than as the wave field moving, which is backwards for this
reference — XMB's motion is in the ribbons themselves. The beat is still the
input; it now moves the thing that is supposed to move.

A beat adds to the drift rate and decays back over ~0.3s, so the ribbons lurch
and settle. **Beat reactivity** scales the surge; at 0 the field just drifts.
Measured by differencing frames 0.35s apart: **3.3% baseline with a 26.7%
spike** on a beat, against the flat crawl it replaced.

The four ripple slots are parked explicitly at a birth time of `-999` rather
than left alone — an unset `vec4` uniform is all zeroes, and a birth time of 0
would have rendered one genuine ripple during the first 2.5 units of the clock,
every launch.

**The desktop wallpaper is unchanged.** Its ripple bus carries *interaction*
points — a workspace switch, a launcher keystroke — where a wavefront is the
right shape for the event: something happened at a point, and the field answers
outward from it. Music has no point of origin, so it gets the whole field
instead. Same shader, two different couplings.

The `rippleSpeed` divide-by-rate fix stays in place and is now inert; the
comment says so, so that re-enabling wavefronts does not silently reintroduce a
wavefront that takes eleven seconds to cross the window.


---

# Screenshot pipeline (roadmap 2.1)

`hypr/scripts/screenshot.sh` replaces two one-line bindings. Region, window or
full; every mode goes to the **clipboard and a file**, and reports what it got.

- `SUPER+S` / `Print` — region
- `SUPER+SHIFT+S` — everything
- `SUPER+ALT+S` — a window; slurp is fed the window rectangles from `hyprctl
  clients` so the selection snaps to edges instead of being traced by hand

Files land in `~/Pictures/Screenshots/` as `YYYY-MM-DD_HH-MM-SS.png`. The old
name was `shot-1755262380.png`, which is not something you can find again.

The notification carries a **thumbnail** and the actions Copy again / Open /
Folder, plus Annotate when `swappy` or `satty` is installed — neither is, so
that button is simply absent rather than broken.

## The shell was advertising two capabilities it did not implement

`NotificationLayer.qml` declared `actionsSupported: true` and
`imageSupported: true`, and `NotificationCard.qml` rendered neither. Every
action any application had ever sent was invisible and uninvokable, and any
attached image was dropped. **A daemon that claims a capability it does not
honour is worse than one that declines it** — senders behave differently based
on that answer, so the failure lands in their code rather than ours.

Both are implemented now:

- Actions render as hairline pills that **bloom on hover** rather than filling
  (design.md §5), so the accent budget is untouched.
- The image renders as a 56px thumbnail. For a screenshot that thumbnail *is*
  the feedback: it says what was captured, not merely that something was.

`Chrome` needed `z: 1` so the buttons sit above the card's drag MouseArea.
Everything else inside it ignores the mouse, so drag-to-dismiss still works
across the whole card.

## Verification

Synthetic clicks cannot be delivered to a layer surface — `hyprctl dispatch
sendshortcut` targets windows — so the click path was proved by hover instead:
with the cursor over the first of two buttons, that button blooms and the other
does not. That establishes the MouseArea is above the drag area and receiving,
and the labels come from `modelData.text`, which establishes the model binds.
Together those are the whole click path.

Also confirmed end to end: file written non-empty, `wl-paste --list-types`
reports `image/png` with valid PNG magic, and `notify-send` releases when the
card's expire timer closes the notification — so a screenshot does not leave a
blocked process behind.


---

# Colour picker (roadmap 2.2)

`SUPER+SHIFT+C` → `hypr/scripts/pick-colour.py`. Hex to the clipboard, and the
answer to the question that actually comes up when you maintain a palette:
**is that one of mine, and if not, how far off is it?**

The notification shows a swatch of the picked colour, the hex, the verdict, and
buttons for copying the hex, the `rgb()` form, or the token name.

## Why CIEDE2000 and not RGB distance

This palette is almost entirely saturated blue, which is the worst case for
naive colour distance. Two blues far apart numerically can be
indistinguishable, while a small numeric step across a hue boundary is obvious.
CIE76 has the same weakness in the blue region — it is the well-known reason
CIEDE2000 was specified at all. Matching in RGB would have produced confident,
wrong answers precisely where this palette lives.

Thresholds come from the same literature rather than taste:

| ΔE | verdict |
|---|---|
| < 1.0 | below the discrimination threshold — "is" |
| < 2.3 | the just-noticeable difference — "matches" |
| ≥ 2.3 | "nearest", with the distance and the runner-up |

Measured against known values: exact tokens come back at ΔE 0.00, `#3579c5`
(one step off the accent) at 0.38 so it reads as *is* the accent, `#4f7fc0` at
2.13 so it reads as *matches* `text-2`, and pure red lands 24.56 from the
nearest ANSI red — far, and correctly reported as far.

## Generic over the token source

The matcher walks `design/tokens.json` collecting every hex-looking value with
a dotted path, rather than naming the groups it knows about. 37 colours today;
a colour added to the token source is matchable without touching the script.
That also means it reports `terminal.ansi[9]`-style names, which are the names
you would actually go and edit.


---

# Now playing in the bar (roadmap 3.1)

`Bar/MediaModule.qml`, in the left cluster after the launchers: title · artist,
a play/pause toggle, and click-the-title to raise the player. Hidden entirely
when no player has a track, so it costs nothing when nothing is on.

Two decisions worth recording:

- **Whichever player is playing wins**, not `players[0]`. A paused browser tab
  would otherwise outrank the thing you are listening to.
- **The title has a fixed width ceiling** (220px, elided). Letting it grow
  freely means the launchers shuffle sideways every time the track changes,
  which turns a status readout into layout jitter.

No accent, per §3 — the toggle is text-1 when playing and text-2 when paused,
the same "quieter state, not a different colour family" the bluetooth and
volume controls already use.

## The icon list was a second source of truth

`design/icons/` holds the SVGs, and `Icon.qml` held a **hand-written array of
the names it serves**. Anything not in that array falls through to the system
icon theme, which returns empty for every status glyph on this machine
(docs/handoff.md) — so dropping `media-play.svg` into the directory was not
enough, and the icon silently did not render. No error, no warning, just
nothing where an icon should be.

The array is now generated from the directory by `build-tokens.py`, so the two
cannot drift again. This is the same class of bug as the notification server
advertising capabilities the card did not implement: a declaration sitting next
to the thing it is supposed to describe, with nothing keeping them in step.

## Verification note

The play/pause toggle's *click* handler is not verified by synthetic input —
clicks cannot be delivered to a layer surface, the same limitation as the
notification action buttons. What is verified from live state: with Spotify
playing, the module shows the correct track and renders the **pause** glyph,
which is the `isPlaying` binding working against real data.


---

# cava (roadmap 3.2)

`cava/config` is generated now. It draws inside the terminal, so it takes the
terminal block like the editor and Spotify do: a blue→cyan gradient, ANSI blue
at the base rising to ANSI bright cyan.

The whole file is generated rather than split ghostty-style into a theme
include, because cava has no include directive — and there was nothing to lose,
the config it replaced set **nothing**: six non-comment lines, all section
headers.

**`background` is deliberately left at cava's default.** Setting it paints an
opaque rectangle over the terminal's own background and destroys the
translucency and blur that took a measured tuning pass to land (8.71:1, see the
terminal section above). A visualiser is not worth that.

## The gradient maps to the screen, not to the bar

First attempt started two steps off the terminal background for subtlety, and
the result was very nearly invisible. cava maps the gradient to the **height of
the screen**, so in a tall terminal the bars sat entirely inside the dark end of
the ramp and read as slightly-lighter background. A bar that reaches a third of
the way up never sees the third stop.

So the ramp starts at a colour that already stands off the background. Every bar
height gets a legible colour, and a peak still resolves to cyan.

## It was drawing nothing at all, and the theme was not why

Before any of that: cava rendered an empty window. Isolated with
`[output] method = raw`, which prints bar values and separates input from
rendering — **218 frames, every value zero.** It was receiving silence, so no
palette would have shown anything.

`[input]` was never configured. It is now `method = pulse`, `source = auto`,
which resolves to the default sink's monitor and therefore follows the output
device rather than naming one — this desk has nine sources and the default moves
between headphones, speakers and SPDIF.

**That is still silent here, and the config is right.** Spotify is routed to
sink 67 (`HiFi__Speaker__sink`) while the default sink is 71 (`C-Media
iec958`). Pointed at the monitor of the sink that actually has audio, cava
reaches peak 96/100 — so cava, pulse and the theme all work, and what remains is
a per-app routing choice rather than something for this repo to hardcode.
Fixing it is either moving Spotify's output to the default sink, or setting
`source` explicitly. The troubleshooting table now names the check.


---

# cava, following the audio

`cava/config` alone could not work on this machine, and not because of anything
in the config. cava's `source` is **static**, and a monitor source only carries
audio played to *that* sink — so any fixed choice is wrong half the time on a
desk that moves between USB speakers and Bluetooth headphones.

`source = auto` follows the **default** sink, which is a different thing again:
pipewire remembers per-application routing, so an app pinned to a non-default
sink leaves cava listening to a device with nothing on it. Measured here: the
default sink was IDLE while Spotify played to a different one, and cava drew an
empty window that looked exactly like a broken theme.

`hypr/scripts/cava-launch.sh` resolves the sink at launch instead of naming one:

1. the sink of a stream that is actually playing (`Corked: no`)
2. failing that, any sink in the `RUNNING` state
3. failing that, the default sink — what cava would have done anyway

Speakers, XM4s, HDMI: whatever is playing when cava starts is what it draws.

It writes a **temp config** rather than editing the real one. The real one is
generated from `design/tokens.json`, and `build-tokens.py --check` fails on
staleness — writing a device name into it would break the build every time the
headphones changed.

The generated config keeps `source = auto`, so running `cava` directly still
behaves sensibly; the launcher is the thing that makes it correct.


---

# Notification history (roadmap 4.1)

`Services/NotificationHistory.qml`, browsable on `SUPER+SHIFT+N`.

**A third launcher mode, not a new surface.** The launcher was already "one UI
over two providers" with the same `query` / `results` / `activate()` / `reload()`
contract, and the README already argues clipboard history belongs there rather
than in a separate picker. A notification history panel would have been a
fourth window with its own chrome, its own search and its own keybinding, for
the same job.

Selecting an entry **copies its text**. The reason you go back to a
notification is almost always a code, a link or a name you now want to paste.

## Persisted, because the failure was losing things

The notification layer is deliberately transient — `keepOnReload: false`, and
cards clear themselves on a timer. That is right for the surface and it is
exactly why a notification you were not looking at was gone for good.

Storage is `FileView` + `JsonAdapter` at `Quickshell.statePath()`, with
`atomicWrites` because the file is rewritten on every notification and a torn
write would lose the entire history rather than one entry. Verified across a
shell restart: three notifications recorded, `pkill -x quickshell`, all three
still listed.

Capped at 200 — enough to answer "what did I miss", not so much that it becomes
a log.

## Two details worth keeping

- **Repeats are collapsed.** Applications that update a notification in place
  (progress, now-playing) would otherwise fill the history with near-identical
  copies of one event, so an entry identical to the newest is dropped.
- **`wl-copy` is invoked as an argument array, never a shell string.**
  Notification bodies are arbitrary remote text and must not be able to become
  a command.

Unqueried, the list is newest-first: a history re-sorted by fuzzy score is not
a history. Same reasoning as the clipboard provider, and the same code shape.


---

# Window switcher (roadmap 4.2)

`Services/Windows.qml`, a fourth launcher mode on `SUPER+Tab` and `ALT+Tab`.

**Searchable, not hold-and-cycle.** Alt+Tab is a good interaction for four
windows and a bad one for fifteen: you tab past the one you wanted and go round
again. Typing two letters is constant-time however many are open, and this desk
routinely has a terminal grid, an editor, a browser and a player across five
workspaces. The `ALT+Tab` binding is there for muscle memory; it opens the same
palette.

Rows are sorted by workspace so the list reads like the desktop is laid out,
and **the focused window sorts last** — it is the one you are already looking
at, so putting it first would waste the top row every time.

Windows are focused by `address:0x…`. Matching on title races with anything
that renames itself, which browsers and editors do on every tab change.

## Two async gaps behind one symptom

Every window that was not on the active workspace displayed as
**"workspace -1"**. Hyprland pushes toplevel changes over its event socket, but
the detail arrives on a refresh, and two separate refreshes are needed:

- `refreshToplevels()` — titles are empty until it lands, so a window opened
  moments ago is filtered out entirely
- `refreshWorkspaces()` — a toplevel's `workspace` handle stays null for
  workspaces the shell has not seen, which is what produced the -1

There is also a fallback to `lastIpcObject.workspace`, which carries the
workspace even before either refresh completes. Verified against `hyprctl
clients`: five ghostty on 1, editor and Claude on 2, browser on 3 — the
switcher agrees on every row.


---

# Idle inhibitor (roadmap 4.3)

A crescent moon in the bar controls, `SUPER+SHIFT+I`, or
`ipc call idle on|off|toggle|status`. Crossed out and in full ink means the
machine will not idle-lock.

**A logind inhibitor, not a signal to hypridle.** `ignore_dbus_inhibit = false`
in `hypridle.conf` means hypridle already honours logind inhibitors, so this is
the supported mechanism rather than a side channel — and anything else that
respects logind gets the same answer for free.

Verified against logind rather than by watching the clock: holding it sets
`BlockInhibited` to `"idle"` and lists as `gelo shell … idle … block`;
releasing clears the property. Both directions, through the IPC handle.

**The inhibitor is the lifetime of a process**, which is a useful property
rather than an implementation detail: if the shell dies, logind releases it and
the machine goes back to locking on schedule, instead of staying awake forever
with nothing left to turn it off.

Full ink only while it is holding. An always-lit control teaches you to stop
seeing it, and the state worth noticing here is the abnormal one.

The new `sleep-off.svg` needed no registration anywhere — the generated icon
list picked it up from the directory, which is the fix from the MPRIS pass
paying for itself.


---

# The token source leaves the desktop

Everything this generator emitted was consumed by *this machine*. Two new
targets are the way out.

## `design/tokens.dtcg.json` — W3C Design Tokens format

What Tokens Studio imports to create **Figma Variables**, and what most token
pipelines read. 58 tokens, every one carrying a `$type`
(`color`, `dimension`, `duration`, `cubicBezier`, `fontFamily`, `fontWeight`,
`number`).

Derived rather than hand-maintained: a second file describing the same colours
is exactly the duplication this generator exists to prevent.

`$description` carries the *reason* where there is one — that accent appears in
exactly three places, that `shade` exists because shadows cannot come from
`bg-0` on a light palette, that `accent-ink` is not called `on-accent` because
QML would read it as a signal handler. **That is the part that does not survive
a copy-paste into Figma**, and the part that stops someone spending the accent
on a fourth thing six months from now.

## `design/tokens.ts` — typed module for web work

`as const` throughout, with `ColorToken` / `SpaceToken` / `RadiusToken` unions.
The point of importing tokens rather than retyping a hex is that a mistake
becomes a type error instead of a slightly-wrong blue nobody notices for a
month. Verified rather than asserted — `tsc --strict`:

```
const typo: ColorToken = "acccent";
  -> TS2820: Type '"acccent"' is not assignable to type
     '"accent" | "accent-dim" | ... '. Did you mean '"accent"'?

const nope = color["not-a-token"];
  -> TS7053: Property 'not-a-token' does not exist
```

Valid usage typechecks clean under `--strict`.

## Why this matters more than another bar module

The desktop, a Figma file and a coursework site can now be the *same palette
object* rather than three copies that drift. One `design/tokens.py` run and
every one of them moves together — and `--check` fails the build if any of them
did not.


---

# Contrast audit (roadmap 5.4)

`design/build-tokens.py --audit` prints every foreground/background pair the
system actually puts together, with its WCAG ratio and the threshold that
applies, and exits non-zero if any fall short.

**The pair list is hand-curated, not generated.** An all-against-all would
produce hundreds of rows nobody reads and would flag combinations that never
occur — `field-base` against `text-1` is meaningless, the wave field has no
text on it. Each row is a claim that this pairing happens, at this threshold.

It audits the **derived** steps too, not just the raw tokens: the editor's
`muted`/`dim`/`hint` ramp and Spotify's subtext step are computed inside the
renderers and are as load-bearing as anything in `tokens.json`. They were
measured by hand during those passes; now they are measured on every run.

## It immediately found a real defect

35 pairs, **3 failures**, all pre-existing:

| pair | ratio | needs |
|---|---|---|
| secondary ink on base surface | 3.62 | 4.5 |
| secondary ink on raised chrome | 3.94 | 4.5 |
| secondary ink on hover surface | 3.34 | 4.5 |

`text-2` (`#5a7fb5`) has failed AA on every light surface since the palette was
inverted, and it is the ink for every subtitle in the shell — the CPU/MEM
labels, the git module, launcher subtitles, notification bodies. Nothing caught
it because the light pass measured the *shader* carefully and the chrome by eye.

The minimal fix is `#466a9d` — same hue (215.6°) and saturation, lightness
0.531 → 0.446, giving 4.88 / 5.31 / 4.51. It stays clearly separated from
`text-1` (luminance gap 0.073), so the two-tier ink hierarchy survives.

That is a palette change affecting every secondary label on the desktop, so it
is gelo's call rather than the build's.


---

# The design system, as a page (roadmap 5.3)

`design/index.html` — one self-contained file, no build step, no dependencies,
opens from disk.

Two properties make it worth *generating* rather than writing:

- **It cannot go stale.** Every swatch, ratio and specimen is read from
  `tokens.json` on the same run that produces the shell, the editor theme and
  the Figma export. `--check` fails if the page falls behind the palette.
- **It is built out of the thing it documents.** The page styles itself with
  its own tokens — the card is `material.chrome`'s gradient and shadow, the
  transitions are `motion.ease`, the type is the type scale, the animated dots
  run on the real bezier. If a token is wrong, the page looks wrong. That is a
  stronger guarantee than a screenshot in a README.

The contrast section is rendered by **the same `audit_pairs()` the build gate
uses**, so the page cannot advertise a ratio the build does not enforce.

## One fix after looking at it

Rows that pass a *lower* threshold — the hairline at 1.3, the accent at 3.0 —
were graded against the 4.5 text bar and displayed as "low". A passing row that
reads as a failure is how a green table gets ignored, so those now show "ok".
The thresholds that apply to a hairline are not the thresholds that apply to
body text.


---

# The bar got quieter, and a dashboard appeared

CPU/MEM/GPU and the git context left the bar. Both were "glanceable" only in
the sense of being permanently visible, and neither was read — **a number you
never look at is texture**. The git module in particular showed a bare commit
SHA, which reads as a mystery ID rather than information.

`Dashboard/` replaces them: month calendar, upcoming events, weather, and the
system meters, behind a deliberate gesture — click the clock, `SUPER+SHIFT+D`,
or `ipc call dashboard toggle`. The system meters gained the bar the numbers
never had, because a percentage is something you read and a bar is something
you glance at.

`Services/Git.qml` and `hypr/scripts/git-context.sh` are deleted rather than
left orphaned.

## Calendar without OAuth

Google and Outlook both publish a **secret ICS address** per calendar. That
avoids app registration, token refresh and a browser round-trip entirely —
`scripts/agenda.py` fetches and parses them.

RRULE expansion is handed to `python-dateutil` rather than reimplemented:
weekly classes and "every other Tuesday" are exactly what a hand-rolled parser
gets subtly wrong. Without dateutil the feed still works and recurring events
simply do not repeat, which is a smaller failure than wrong dates. Verified
against a synthetic feed covering folded lines, all-day events, timezone
conversion and `FREQ=WEEKLY;BYDAY=MO,WE,FR`.

**The URLs are bearer secrets**, so they live in `~/.config/gelo/calendars.json`
— outside this repo, because the repo is `~/.config` and is pushed. Nothing
prints a URL, including on failure: errors report `name: ExceptionType`.

## Two things the panel taught us about the material

**Chrome is 96% opaque, and that is only correct over the wallpaper.** Measured
with an editor behind it, the bleed was 8.3% — enough to read VS Code's file
tree through the calendar. The fix is not to make the material denser
everywhere: the bar was tuned against the wallpaper and looks right. `Chrome`
gained an `opaque` opt-out for surfaces that float over arbitrary windows, and
the dashboard cards take it. Bleed measured afterwards: ~0, the residual being
the card's own content.

A scrim from `shade` sits behind the panel as well — it says the panel is
modal, which it is, and it is where every other scrim in the system comes from.

**A `MouseArea` cannot be a child of a `Row`.** Making the clock clickable with
one produced `Cannot specify left, right, horizontalCenter, fill or centerIn
anchors for items inside Row` — and it would have taken a slot in the layout.
`TapHandler` and `HoverHandler` do not participate in positioner layout at all,
which is what they are for.


---

# The site (roadmap 5.3, 5.5)

`design/index.html` became four pages under `docs/`, which is a GitHub Pages
source directory:

| | |
|---|---|
| `index.html` | the system — palette, type, space, motion, the live contrast table |
| `xmb.html` | the wave field: three approaches, two failures, one shader on two runtimes |
| `accessibility.html` | the audit, what it found, and why album tinting cannot break contrast |
| `bridge.html` | one source → twelve targets → Figma Variables and typed TS |

Generated, for the same two reasons the single page was: it cannot go stale
(`--check` fails if it falls behind the palette), and **it is styled by the
tokens it documents** — a page about a design system that does not use it is a
screenshot with extra steps.

`.nojekyll` is included so Pages serves the HTML as written rather than running
it through Jekyll, which would try to interpret the Markdown alongside it.

The split is by *argument*, not by feature: each page makes one claim and shows
the evidence for it. The material was already there — `CHANGES.md` records the
failures, and failures are the part of a portfolio that is usually missing.


---

# `SUPER+S` was two bindings

Stock Hyprland puts the scratchpad on `SUPER+S` / `SUPER+SHIFT+S`. The
screenshot binds added later took the same chords, and Hyprland does not resolve
that — it fires **every** binding matching a chord. `hyprctl binds` showed two
entries for modmask 64 + `S`, so pressing it started a region selection *and*
toggled the special workspace underneath it.

The scratchpad moved to `` SUPER+` ``. Verified after `hyprctl reload`: three
`S` entries, all screenshot; two `grave` entries, both scratchpad.

This is the same rule that put clipboard history on `SUPER+SHIFT+V` rather than
`SUPER+V` — it was already written down, and the screenshot binds still walked
into it. `hyprctl binds` is the check: two entries with the same `modmask` and
`key` is always a collision, never a precedence.

---

# README as a getting-started document

The README had been edited incrementally for every feature and never read end to
end as a stranger would read it. Auditing it against the tree found the
documentation drifting from the config in ways that would only surface on
someone else's machine:

| Was | Actually |
|---|---|
| symlink loop covered 9 directories | 13 exist; the warning below it already said "13 dangling links" |
| `pacman -S` list | missing `nautilus`, `pavucontrol`, `python-dateutil`, `imagemagick`, `xdg-desktop-portal-hyprland` — all reachable from a default keybind or a visible card |
| "roll back by: uncomment `waybar-launch`" | that wrapper lives in `~/.local/bin`, outside this repo |
| nothing about monitors or the NVIDIA `env` block | both hardcode my hardware; both break a first login |
| Known gaps: one bullet | SDDM, polkit, wallpaper occlusion, distro scope and packaging were all undocumented |

`python-dateutil` is the one worth naming twice: it was in neither the package
list nor the machine, and without it the agenda parses fine and simply
under-reports — a weekly class appears once and then never again. A silent
degrade needs a louder note than a crash does.

New sections: **Before you start** (what installing this actually replaces, the
four machine-specific values, back up first, and that the token layer is usable
on its own), and **Did it work?** — five commands in the order things fail,
each with what a pass looks like.


---

# `format` tokens: 12-hour clock, imperial units

Two settings that were four and two hardcoded literals respectively.

**The clock.** `"HH:mm"` appeared in `Bar/Clock.qml`, `Lock/LockContent.qml`
and the SDDM greeter's `Main.qml`, and `agenda.py` had its own `%H:%M`. Changing
the format meant changing four files, and a desktop that says 3:45 PM on the bar
and 15:45 on the lock screen is the same class of failure as two shades of the
same blue — so it became a token like every other cross-surface decision.

`Tokens.format.timePattern` resolves to `"h:mm AP"` or `"HH:mm"` and goes
straight into `Qt.formatDateTime`. `h` rather than `hh`: 3:45 PM, not 03:45 PM.

`agenda.py` gets `clock` as `argv[2]` instead of reading tokens itself. It has
no path back into the repo on purpose — it is the one script handling bearer
secrets, and the fewer files it can reach the better. The caller already holds
the token.

Formatting the 12-hour string by hand rather than with `%-I`: that flag is a
glibc extension, `%I` pads to two digits, and there is no portable strip-zero
directive. `strftime("%I:%M %p").lstrip("0")` covers it — and does not eat the
`1` of `12:45 AM`, which was the case worth checking.

**Units.** wttr's `j1` payload carries `temp_C` *and* `temp_F`, so Fahrenheit is
a field choice, not a conversion — no rounding error introduced, and no drift if
wttr changes how it rounds. Precipitation is only published in mm and is
converted.

That conversion moved the visibility rule. The bar hid the precipitation readout
on `precipitation > 0`, which under imperial leaves 0.1mm — 0.0039in, rendering
as `"0.00in"` — passing the test. Gating on the *rendered* value instead
(`hasPrecipitation`) keeps the rule doing what it was written to do: no
permanent "no rain" readout in a row that is glanced at rather than read.

**Layout.** `12:45 PM` is wider than `15:45`, so the agenda's time column went
from a flat 52px to 74 under a 12-hour clock. Sizing to the 24h string would
have elided the meridiem, which is the one part that matters.

Measured live after restart: bar reads `Mon 17 Aug 10:20 AM` and
`73°F 0.52in` (13mm → 0.52in ✓); the agenda reads `9:35 AM`, `12:45 PM`,
`2:00 PM`, `5:30 PM` with no elision. Shell log clean.


---

# fastfetch: what I am sitting in, not what the box is

`display`, `cpu` and `gpu` out; `wm`, `shell`, `terminal` in.

The three that left are static facts about a desktop that does not change —
printing them on every shell start is a screensaver, not information. The three
that arrived are the things that actually vary between one invocation and the
next: which compositor, which shell, which terminal emulator. CPU/MEM/GPU are
live in the dashboard, which is where a number belongs if you want to watch it
move.

The colour header was also wrong. It documented `text-1`/`text-2`/`chrome-edge`
and cited values the palette had moved past two changes ago — `chrome-edge` no
longer exists, and `text-2` went `#5a7fb5` → `#466a9d` in the AA fix. More
importantly the framing was wrong: fastfetch renders on the **terminal**
background (`#14293f`, dark), not on chrome (`#f8fbff`, light), so the UI text
tokens would be dark-on-dark here. The values now come from and cite the
`terminal` block, and the separator moved to `ansi[8]`, the palette's designated
dim.

---

# The dock (bar → bottom edge)

The pinned launchers left the bar.

They were five pieces of untinted outside colour — real app logos — sitting
permanently next to the workspace blob, the one element allowed to carry the
accent. The bar had to stay quiet around them and they had to stay small (18px)
to not shout. Moving them out gives both back what they wanted.

**Auto-hiding, bottom, centred.** A dock that is always up is a strip of screen
you have stopped seeing, which is the same argument that moved CPU/MEM/GPU into
the dashboard.

## The input mask is the whole feature

A layer surface captures the pointer across its **entire** area regardless of
what it paints. An unmasked full-width panel at the bottom of the screen eats
every click along that edge — every taskbar-shaped piece of muscle memory in
whatever is running maximised.

`PanelWindow.mask` narrows the input region. It is switched between two items
rather than animated:

| State | Live region |
|---|---|
| hidden | `strip` — `revealStrip` (6px) at the very bottom, plate width + one step each side |
| open | `hitArea` — the full panel height |

`hitArea` spans from the top of the plate **down to the screen edge**, not just
the plate. The plate floats above an 8px bottom margin, so a mask covering only
the plate excludes the exact strip the pointer is standing on at the instant of
reveal: hover drops, dock hides, mask returns to the strip, hover fires again.
It oscillates.

Verified live by driving the cursor and screenshotting:

| Pointer | Result |
|---|---|
| y=1400 (inside the panel, above the strip) | stays hidden, cursor renders as the window's own — input passes through |
| y=1439 (in the strip) | reveals |
| y=1380 (on the plate, after revealing) | stays open, icon under the pointer magnifies |
| moved away | hides after `hideDelay` |

## Click means "show me it"

Left-click focuses the app if it is already open and launches only if it is not.
Getting a second copy of a running app is exactly what an indicator exists to
prevent — you can see it is open, so the click can only mean one thing.
Middle-click still forces a new instance.

`Windows.matching()` does the lookup by **class prefix, case-insensitively**,
because the icon name and the window class disagree constantly: VS Code ships
its icon as `vscode` and reports its class as `code`. Prefix rather than
equality covers Chrome's per-channel classes without enumerating them — an app
silently reading as "not running" because of a suffix is a worse failure than
the occasional over-match.

## The indicator is not the accent

A dot in `text-2`, widening to a short bar for more than one window. The accent
is spent on three things system-wide (design.md §3) and "an app is open" is not
one of them; this is the same mark the dashboard calendar puts under a day that
has something on it, for the same reason. A row of N dots was the other option
and it stops being countable at three, then becomes texture.

## Two things that bit

**`Behavior` on a `readonly property`** is a hard error, not a no-op:
`Invalid property assignment: "iconSize" is a read-only property`. The animation
needs somewhere to write intermediates.

**`ipc call dock show` never reached the handler.** `show` is the quickshell
CLI's own subcommand (`quickshell ipc show` lists targets), so the call printed
the target listing and **exited 0** — indistinguishable from success. Renamed to
`open`/`close`. Worth knowing generally: a zero exit from `ipc call` does not
mean the function ran.

**The IpcHandler could not live in the dock.** The dock is per-screen like the
bar, and `IpcHandler` registration is process-wide — the second instance is
dropped with a warning and `ipc call dock …` silently only ever reaches one
monitor. It moved to `Services/DockState.qml`, a singleton holding a `forced`
flag that every dock ORs with its own hover state. Same constraint that makes
the launcher single-instance.

## Also fixed in passing

Restarting the shell surfaced a pre-existing warning: `Dashboard.qml:100`,
*"Cannot specify anchors for items inside Row. Row will not function."* A
click-swallowing `MouseArea` was breaking the dashboard panel's layout — the
same trap `Clock.qml` already documented. Replaced with a `TapHandler`, which is
not an item and takes no slot in the positioner.


---

# Dock: the indicator that never fired

Obsidian sat in the dock with no running indicator no matter how many windows it
had open. Nothing errored; the app simply read as closed forever.

`Windows.matching()` compared by lowercase **prefix**, and Obsidian reports its
class as `md.Obsidian` while its icon is `obsidian`. `"md.obsidian"` does not
start with `"obsidian"`, so the test could never pass. The same hole covered
every reverse-DNS class in the system — `com.anthropic.Claude`,
`org.gnome.Nautilus`, `com.mitchellh.ghostty`.

The obvious fix is a substring test, and it is the wrong one. `obs` is a
substring of `obsidian`, so the moment OBS Studio joined the dock the two would
light each other's indicators and steal each other's clicks.

Three ordered rules instead, all case-insensitive:

| Rule | Example |
|---|---|
| the whole class | `obs` matches `obs` |
| the last dot-segment | `obsidian` matches `md.Obsidian` |
| a hyphenated suffix | `google-chrome` matches `google-chrome-beta` |

Checked every real class on this machine — observed via `hyprctl clients` plus
the `StartupWMClass` of each `.desktop` file — against all nine dock entries:
each resolves to exactly one owner, no collisions, and the two unclaimed
classes (`localsend`, and OBS's alternate `com.obsproject.Studio`, since added
explicitly) are correctly unclaimed rather than mis-assigned.

Confirmed live: Claude is `com.anthropic.Claude` and now shows its dot, which is
the same code path Obsidian takes.

**Four apps added** — Files, Claude, Spotify, OBS — bringing the dock to nine,
ordered by what the desk is for: shell, editor, browser, files, notes,
assistant, music, capture, 3D. Icon names came from the desktop entries
(`spotify-client`, not `spotify`; `claude-desktop`, not `claude`) and were
checked against the icon theme before being committed rather than after.

**Rounder plate.** `material.dock.radius` (22) instead of the shared
`material.chrome.radius` (8). Every other surface in the system is anchored to a
screen edge, where 8px reads as a machined corner; the dock floats free with
nothing touching it, and at that size the same radius reads as a rectangle that
forgot to commit.


---

# Dock: the indicators were stale, not wrong

The class-matching fix was real, but it was not the whole bug. Indicators still
did not appear when an app was opened — only after something *else* happened to
open the launcher.

`Windows.reload()` was called from exactly one place: `Launcher.qml`, when the
window-switcher mode opens. That was correct while the launcher was the only
consumer — you ask for the window list, it gets fetched. The dock reads the same
service *continuously*, and inherited whatever happened to be cached.

The failure is silent for a specific reason. `entries` drops any toplevel with an
empty title, and an un-refreshed toplevel **has** an empty title — Hyprland's
event socket announces that a window exists, but the title and class only land
on a follow-up IPC query. So a window that just opened is indistinguishable from
one that does not exist. No error, no empty state, just an app that reads as
closed forever.

`Windows` now refreshes itself off `Hyprland.rawEvent`, on the events that
change the set or the ordering:

    openwindow  closewindow  movewindow  windowtitle  windowtitlev2
    activewindow  activewindowv2

Coalesced through a 60ms timer, because opening a single window emits five of
those within a few milliseconds and that is one refresh, not five. No feedback
loop is possible: `refreshToplevels()` is a query against Hyprland's socket, and
queries do not emit events.

Measured, with the dock open and the launcher never touched:

| | dots |
|---|---|
| before | VS Code, Chrome, Claude |
| open Nautilus + Ghostty | Ghostty, VS Code, Chrome, Files, Claude |
| close both | VS Code, Chrome, Claude |

The general lesson is worth keeping: a service written for a pull consumer grew
a push consumer, and the change of consumer — not the code — is what made it
wrong. The launcher's explicit `reload()` on open stays as a guarantee.


---

# Three bar panels, and the exclusive-zone rule that shapes them

The bar was one full-width plate. Chrome in this system is an *object* sitting
above the desktop, and a plate spanning the whole screen stops reading as an
object and starts reading as a frame — the wave field only ever touched it along
one edge. Three plates put the field back between them.

## It is still one surface, and it has to be

The obvious build is three `PanelWindow`s. It does not work. Hyprland only
honours a layer surface's exclusive zone if that surface **spans** its anchored
edge — so three side-by-side surfaces reserve nothing, and every window sits
underneath the bar.

Measured against a clean baseline (no shell running at all), with the property
read back to confirm it really was set:

| Anchors | mode | zone | `hyprctl monitors` reserved |
|---|---|---|---|
| top+left+right | Auto | — | `[0,56,0,0]` |
| top+left+right | Normal | 56 | `[0,56,0,0]` |
| top+left | Normal | 56 | `[0,0,0,0]` |

So: one spanning surface keeps the exclusive zone, three `Chrome` plates are
drawn inside it, and `mask` narrows the **input** region to the plates via three
`Region`s combined with `Intersection.Combine`. The gaps are click-through,
which matters when a fullscreen window is underneath. Verified by hovering a
tray icon and seeing the pointing-hand cursor appear — hover only reaches a
MouseArea inside a masked-in region.

Two things this cost, both worth recording:

**`exclusionMode` defaults to `Auto`**, which derives the zone from the anchors
and discards `exclusiveZone` entirely. The first attempt set `exclusiveZone`
alone and reserved nothing.

**Hyprland adds `margins.top` on top of the requested zone.** Asking for
`height + margin` reserved 64 instead of 56. The request is the height; the
compositor supplies the gap.

A measurement note on the first of those: an early probe reported that the
*spanning* case also failed, which would have been a much bigger problem. That
reading was wrong — a previous probe instance had not exited when the
measurement was taken. Re-run with an explicit `pkill` and a verified
`reserved=[0,0,0,0]` baseline first, spanning worked. Two conclusions from one
unreliable harness is one too many.

## Tray: Claude and NordVPN out

`TrayRow` grew an `ignore` list. A tray icon is a claim on permanent screen
space and neither of those earns it — neither has anything to *report*; they are
launchers wearing a status icon, and both apps are one click away in the dock.

Matched as a substring of `id` + `title`, not by equality: Claude registers as
`Claude_status_icon_1` and that counter increments if the app restarts while the
shell is running. Its `title` is empty, so matching on title alone would have
silently never fired. Ids were read off the live host — a second Quickshell
instance cannot probe them, because the tray host is a single-owner DBus name.

Filtered by `visible: false` on the delegate rather than by wrapping the model:
`SystemTray.items` is an ObjectModel with no filtering view, and QtQuick
positioners skip invisible children, so there is no gap where the icon was.

## Dock: no reflections, rounder

`Reflection` draws its mirror *below* its own bounds, so it needed a third of the
plate reserved as empty space for the mirror to land in — and it pushed the
running indicator far enough from its icon to read as belonging to the plate.
The bar has width to spare and the dock does not; the water effect needs
somewhere to be water. The plate lost ~24px of height with it.

Radius 22 → 28, and the bar's plates went 8 → 16 (`material.bar.radius`). At 8px
a free-floating 48px plate reads as a strip that was cut off rather than an
object.
