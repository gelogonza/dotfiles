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
motion and the glass material are defined there once, and
`design/build-tokens.py` fans them out to every consumer:

| Generated | Consumed by |
|---|---|
| `quickshell/gelo/Theme/Tokens.qml` | the shell |
| `sddm/themes/gelo-liquid/Theme/Tokens.qml` | the login theme |
| `design/tokens.css` | GTK / Waybar fallback tier |
| `hypr/tokens.conf` | `hyprland.conf`, `hyprlock.conf` |
| `*/Components/Glass.qml` | both QML roots, from `design/qml/Glass.qml` |
| `*/Shaders/fluid.frag` | both QML roots, from `design/shaders/fluid.frag` |

Four languages, two QML roots that cannot import each other (the login theme is
installed to `/usr/share` and cannot read `$HOME`, which is mode 700). Generating
is what keeps them from drifting.

```bash
design/build-tokens.py           # regenerate everything
design/build-tokens.py --check   # fail if anything is stale (CI / pre-commit)
design/build-shaders.sh          # bake .frag -> .qsb (Qt6 rejects raw GLSL)
```

Generated files carry a do-not-edit header and are committed, so a fresh clone
works without running anything.

### Rules the system actually enforces

**Accent appears in exactly three places.** Active workspace indicator, focused
window border, cursor. Nowhere else. Selection states, hover states, notification
urgency and login failure all carry meaning through elevation, weight and
opacity instead. Failure states reuse `--accent` at low opacity rather than
introducing a red — a fourth colour would also be a fourth accent location.

**Everything snaps to a 4px grid**, including the bar height, the blob, and the
password field.

**One motion curve** — expo-out `cubic-bezier(0.16, 1, 0.3, 1)` — shared by QML
animations, Hyprland window animations and hyprlock.

### Liquid glass

Three rules, applied identically everywhere:

1. Depth from a soft, large-radius, low-opacity **shadow** — never a gradient
   "shine". That is the difference between Apple and Windows Aero.
2. A **1px specular highlight on the top edge only**, held across the span and
   faded at the ends.
3. On interaction the **corner radius relaxes outward** rather than snapping to
   a hover state. The morph is the affordance.

The backdrop blur is **not** done in Qt — a Wayland client cannot sample what is
behind its own surface. Each shell surface declares a
`WlrLayershell.namespace`, and `hypr/gelo.conf` matches a `layerrule` against it
so the compositor does the frosting. That is why the material needs a
compositor-side half.

---

## Components

**Wallpaper** — the fluid shader on the background layer. Also what gives the
glass something to refract: over the previous near-black wallpaper the bar
measured 17/255 mean brightness and read as flat paint; over the shader it
measures 29 with a third of its pixels changing as the field moves.

**Bar** — workspaces, window title, git context, tray, clock.
The workspace indicator is the blob: its two edges animate independently
(leading fast, trailing slow), so it stretches across the gap and settles rather
than sliding. Measured 24px → 37px → 24px through a switch.
The **git module** resolves the repo from the focused window by walking its
process tree shallowest-first, so a terminal sitting in `$HOME` correctly falls
through to the shell that is `cd`'d into your project.

**Launcher** (`SUPER+R`, `SUPER+D`) — command palette. Fuzzy subsequence ranking
with bonuses for word-start and contiguous runs. Rows arrive staggered.
Also scriptable:

```bash
qs -c gelo ipc call launcher toggle
qs -c gelo ipc call launcher search fire
```

**Notifications** — glass cards, slide in from the right, drag or click to
dismiss with a squash-and-release. Critical notifications stay until acknowledged.

**Lock** (`SUPER+L`) — deliberately plain. Glass on the password field, no
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

- **Cursor accent is unimplemented.** Two of the three sanctioned accent
  locations are done (workspace indicator, window border). Recolouring the
  cursor requires generating a custom hyprcursor theme.
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
