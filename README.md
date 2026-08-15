# dotfiles

Hyprland desktop built as a design system: one token source, one material, one
motion curve, applied across the bar, launcher, notifications, lock screen and
login screen.

```
design/          design system — token source + generator + shared QML/GLSL
quickshell/gelo/ the shell: wallpaper, bar, launcher, notifications
sddm/            login theme (installed to /usr/share, see docs/login-screen.md)
hypr/            compositor config
docs/            procedures with real failure modes
reference/       upstream material kept for reference, not loaded at runtime
```

---

## The design system

**`design/tokens.json` is the single source of truth.** Colour, spacing, type,
motion and the chrome material are defined there once, and
`design/build-tokens.py` fans them out to every consumer:

| Generated | Consumed by |
|---|---|
| `quickshell/gelo/Theme/Tokens.qml` | the shell |
| `sddm/themes/gelo-liquid/Theme/Tokens.qml` | the login theme |
| `design/tokens.css` | GTK / Waybar fallback tier |
| `hypr/tokens.conf` | `hyprland.conf`, `hyprlock.conf` |
| `*/Components/{Chrome,Glow,Reflection}.qml` | both QML roots, from `design/qml/` |
| `*/Shaders/xmb.frag` | both QML roots, from `design/shaders/xmb.frag` |

Four languages, two QML roots that cannot import each other (the login theme is
installed to `/usr/share` and cannot read `$HOME`, which is mode 700). Generating
is what keeps them from drifting.

```bash
design/build-tokens.py           # regenerate everything
design/build-tokens.py --check   # fail if anything is stale (CI / pre-commit)
design/build-shaders.sh          # bake .frag -> .qsb (Qt6 rejects raw GLSL)
design/build-cursor.py           # recolour the cursor theme (run once per clone)
```

`build-cursor.py` writes to `~/.local/share/icons/gelo-cursor` rather than into
the repo: it is ~12MB of binaries derived from Adwaita (CC-BY-SA 3.0), and
carrying a recoloured copy here would drag the attribution along with it.

Generated files carry a do-not-edit header and are committed, so a fresh clone
works without running anything.

The visual language is **PS3 XMB**: cold near-black blue, one glowing cyan
accent, chrome surfaces, geometric type (Michroma), and motion that lives in the
wave field behind the interface.

### Rules the system actually enforces

**Accent appears in exactly three places.** Active workspace indicator
(`BlobIndicator`), focused window border (`col.active_border`), and the cursor
(`design/build-cursor.py`). Nowhere else. Selection states, hover states, notification
urgency and login failure all carry meaning through elevation, weight and
opacity instead. Failure states reuse `--accent` at low opacity rather than
introducing a red — a fourth colour would also be a fourth accent location.

**Everything snaps to a 4px grid**, including the bar height, the blob, and the
password field.

**One motion curve** — `cubic-bezier(0.22, 1, 0.36, 1)` — shared by QML
animations, Hyprland window animations and hyprlock. `--dur-slow` (400ms) is
specifically the ripple propagation time.

**Weight is not a hierarchy tool.** Michroma has exactly one weight, so
hierarchy comes from size, opacity, tracking and glow.

### Chrome / reflection

The material language is brushed metal, glow and reflection — **not** frosted
glass. There is no backdrop blur anywhere, and the compositor layerrules that
used to produce it have been removed.

1. **Brushed metal.** Raised surfaces carry a vertical gradient, `bg-1` fading a
   few percent darker at the bottom. Enough to read as material, not enough to
   read as a gradient.
2. **Selection is glow, not outline or fill.** Nothing gets boxed when selected;
   it blooms. `Glow.qml` renders a blurred, accent-tinted, enlarged copy of the
   content behind it.
3. **Reflection beneath elements** — a flipped, faded, gradient-masked copy.
   `Reflection.qml`. It samples the slice at the waterline, not the top of the
   item, or the mirror comes out as a disconnected fragment.
4. **Motion lives in the wave field behind the UI.** Interactions emit a ripple
   that propagates through the wallpaper shader (`Services/Ripples.qml` →
   `Shaders/xmb.frag`).

The one exception to rule 4 is the workspace indicator, which keeps its
travelling blob: the element moves *and* the field responds.

---

## Components

**Wallpaper** — the XMB wave field on the background layer, and the surface every
interaction ripple propagates through. It is a **ribbon** field: explicit sine
curves with gaussian falloff, not fBm noise. Noise reads as smoke; XMB is smooth
horizontal bands of light. Also carries no accent — the field is built from
`bg-1`/`bg-2`/`border` only, so the accent budget stays intact.

**Bar** — workspaces, window title, git context, tray, clock.
The workspace indicator is the blob: its two edges animate independently
(leading fast, trailing slow), so it stretches across the gap and settles rather
than sliding. Measured 24px → 37px → 24px through a switch.
The **git module** resolves the repo from the focused window by walking its
process tree shallowest-first, so a terminal sitting in `$HOME` correctly falls
through to the shell that is `cd`'d into your project.

**Terminal** — dark steel-blue, translucent, blurred, so it sits in the wave
field rather than punching a hole in it. Theme generated from tokens into
`ghostty/gelo-theme`. Measured text contrast 8.71:1 (WCAG AAA).

**Launcher** (`SUPER+R`, `SUPER+D`) — command palette. Fuzzy subsequence ranking
with bonuses for word-start and contiguous runs. Rows arrive staggered.
Also scriptable:

```bash
qs -c gelo ipc call launcher toggle
qs -c gelo ipc call launcher search fire
```

**Notifications** — chrome cards, slide in from the right, drag or click to
dismiss. Arriving and dismissing both ripple the field. Critical notifications
stay until acknowledged.

**Lock** (`SUPER+L`) — deliberately plain. Chrome on the password field, no
shader. This is the path back into a running session, so it should feel instant.

**Login** — the one surface with a real GLSL shader. See
[docs/login-screen.md](docs/login-screen.md); it is not active until you switch
display managers, and that file has the recovery procedure.

---

## What replaced what

| Was | Now | Rollback |
|---|---|---|
| Waybar | Quickshell bar | uncomment `waybar-launch` in `hyprland.conf` |
| wofi / hyprlauncher | Quickshell launcher | `$menu` in `hyprland.conf` |
| mako | Quickshell notifications | uncomment `exec-once = mako` |
| hyprpaper | shader wallpaper | uncomment `exec-once = hyprpaper` |
| GDM | SDDM (opt-in, not yet active) | see docs/login-screen.md |

All compositor-side changes live in `hypr/gelo.conf`, sourced by one line at the
bottom of `hyprland.conf`. Delete that line to revert every one of them.

`org.freedesktop.Notifications` is a single-owner DBus name — running mako
alongside the shell means whichever starts first wins and the other silently
does nothing.

---

## Known gaps

- **hyprlock is unverified.** The config is written and bound, but hyprlock has
  no dry-run mode and a failed lock can leave a session locked, so it was not
  tested. Test it deliberately: `hyprlock --grace 30` lets any keypress dismiss
  it without a password. Keep a TTY (`Ctrl+Alt+F2`) available the first time.
- **The wallpaper shader does not stop when occluded.** wlr-layer-shell exposes
  no occlusion signal, so it keeps rendering behind maximised windows. If
  battery or thermals matter, replace the `Wallpaper{}` block with a static
  image rather than micro-optimising the shader.
- **Quickshell's `DesktopEntries` returns nothing** on this system (both
  `byId()` and `heuristicLookup()` return null), which is why the launcher
  builds its own index via `scripts/list-apps.py`.
