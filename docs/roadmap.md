# Roadmap

Where this is going next, and why. Written after the desktop itself was
finished — the remaining work is about **reach** (the system stopping at the
desktop edge) and **completeness** (things the shell still cannot do).

Status legend: ☐ not started · ◐ in progress · ☑ done

---

## 1. Extend the design system into the apps ◐

The problem: `design/tokens.json` themes the desktop, terminal, login, lock and
GTK — then you open VS Code and stare at an unrelated palette for eight hours.

| | Target | Approach | Status |
|---|---|---|---|
| 1.1 | VS Code | generated theme extension in `vscode/gelo-xmb/` | ◐ generated, not yet installed or verified |
| 1.2 | Obsidian | CSS snippet into `Gelo's Vault/.obsidian/snippets/` | ☐ |
| 1.3 | Spotify | spicetify `color.ini` (spicetify 2.44 already installed) | ☐ |

**Key decision — the editor is dark, and that is deliberate.** The desktop
chrome is light; the terminal already is not. The editor theme is derived from
the **`terminal` token block**, not the UI palette, so an editor split and a
terminal split side by side are the same colour. Syntax colours are the ANSI
set, meaning a diff in the terminal and the same diff in the editor are
literally the same greens and reds.

Rule of thumb this establishes: **surfaces you work *in* are dark; chrome you
work *with* is light.**

Spicetify carries the only real risk here — it patches the Spotify install
rather than layering a config, so it needs `spicetify restore` documented before
it is applied.

Both currently run **Halcyon**, which is what these replace.

## 2. Design-engineer workflow tools ☐

| | Item | Why |
|---|---|---|
| 2.1 | Screenshot pipeline | today it is `grim` to `~/Pictures/shot-<epoch>.png` with no clipboard copy and no feedback — you cannot tell it worked. Wanted: region / window / full, to **clipboard *and* file**, with a notification carrying copy / open / annotate actions |
| 2.2 | Colour picker | `hyprpicker` → hex on the clipboard, and report **which design token it matches**, or the nearest one. Bespoke to someone maintaining a palette; nothing off-the-shelf does it |

## 3. Music and ambience ☐

| | Item | Why |
|---|---|---|
| 3.1 | MPRIS now-playing | `Quickshell.Services.Mpris` is available and unused; Spotify is essentially always running. Track title + play/pause in the bar |
| 3.2 | cava theming | `cava/config` is in the repo and still on stock colours |

## 4. Shell completeness ☐

| | Item | Why |
|---|---|---|
| 4.1 | Notification history | a missed notification is currently gone forever — nothing persists them |
| 4.2 | Window switcher | no Alt+Tab equivalent |
| 4.3 | Idle inhibitor toggle | hypridle locks at 5 min; a bar toggle to suppress it during video. Browsers do appear to inhibit correctly here (one inhibitor was active during testing), so this is a safety net rather than a fix |

---

## Carried-over gaps

These predate the roadmap and are still open:

- **Neither lock has completed a real unlock cycle.** hyprlock is on `SUPER+L`,
  the Quickshell lock on `SUPER+SHIFT+L`, and **hypridle now fires hyprlock at
  5 minutes** — so this is no longer hypothetical. See `docs/lock-screen.md`;
  test deliberately with a TTY open.
- **SDDM login is installed but not enabled.** `docs/login-screen.md` has the
  switch and the recovery procedure.
- **The wallpaper shader does not stop when occluded** — wlr-layer-shell exposes
  no occlusion signal. If battery or thermals ever matter, swap the
  `Wallpaper{}` block for a static image rather than micro-optimising GLSL.
- **`hyprpolkitagent` renders stock, not XMB.** Quickshell exposes a
  `PolkitAgent` type, so a themed replacement is possible — but an auth prompt
  is the wrong place to discover a service does not work, so it stays until
  there is appetite to verify it properly.

## Principles that constrain all of the above

From `design.md §10` — worth re-reading before adding a surface:

1. Accent appears in exactly **three** places. A fourth is a redesign.
2. No warm hues, except terminal ANSI 1/3/9/11 where they are load-bearing
   semantics.
3. Everything on the 4px grid.
4. Weight never exceeds 400.
5. Never edit a generated file — edit the source in `design/`.
