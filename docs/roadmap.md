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
| 1.1 | VS Code | generated theme extension in `vscode/gelo-xmb/` | ☑ installed and verified |
| 1.2 | Obsidian | CSS snippet into `Gelo's Vault/.obsidian/snippets/` | ☐ |
| 1.3 | Spotify | spicetify `color.ini` (spicetify 2.44 already installed) | ☑ applied and verified |

⚠️ **Setting `workbench.colorTheme` alone does nothing on this machine.**
Something in this session reports high contrast to Electron, so VS Code obeys
`workbench.preferredHighContrastColorTheme` and ignores the normal setting. A
theme installed the obvious way appears to be a no-op. Both keys must be set.
See `docs/CHANGES.md`.

**Key decision — the editor is dark, and that is deliberate.** The desktop
chrome is light; the terminal already is not. The editor theme is derived from
the **`terminal` token block**, not the UI palette, so an editor split and a
terminal split side by side are the same colour. Syntax colours are the ANSI
set, meaning a diff in the terminal and the same diff in the editor are
literally the same greens and reds.

Rule of thumb this establishes: **surfaces you work *in* are dark; chrome you
work *with* is light.**

Spicetify carried the only real risk here — it patches the Spotify install
rather than layering a config. `docs/spotify.md` was written before it was
applied and covers restore, the backup-invalidation trap, and recovery.

Obsidian currently runs **Halcyon**, which is what 1.2 replaces. VS Code did
too, until 1.1 landed; Spotify was on StarryNight/**orange**, which 1.3
replaced — the one place in the system that was still running a warm hue.

## 2. Design-engineer workflow tools ☑

| | Item | Why |
|---|---|---|
| 2.1 | Screenshot pipeline | ☑ `hypr/scripts/screenshot.sh` — region / window / full, to clipboard **and** file, with a thumbnail notification carrying copy / open / folder / annotate |
| 2.2 | Colour picker | ☑ `hypr/scripts/pick-colour.py` — hex to the clipboard, and the nearest token by CIEDE2000 with the distance |

## 3. Music and ambience ☑

| | Item | Why |
|---|---|---|
| 3.1 | MPRIS now-playing | ☑ `Bar/MediaModule.qml` — title · artist and a play/pause toggle in the left cluster; click the title to raise the player |
| 3.2 | cava theming | ☑ `cava/config` is generated — blue→cyan gradient from the terminal block |

## 4. Shell completeness ☑

| | Item | Why |
|---|---|---|
| 4.1 | Notification history | ☑ `Services/NotificationHistory.qml`, browsable as a third launcher mode on `SUPER+SHIFT+N`; persisted, so it survives a shell restart |
| 4.2 | Window switcher | ☑ `Services/Windows.qml`, a fourth launcher mode on `SUPER+Tab` / `ALT+Tab` — searchable rather than hold-and-cycle |
| 4.3 | Idle inhibitor toggle | ☑ `Services/IdleInhibitor.qml` — bar toggle, `SUPER+SHIFT+I`, or `ipc call idle on/off/toggle` |

---

## Carried-over gaps

These predate the roadmap and are still open:

- ~~Neither lock has completed a real unlock cycle.~~ **Both verified by gelo,
  2026-08-15.** The Quickshell shader lock is now the default: `SUPER+L`, the
  power menu and hypridle's 5-minute timeout all route through
  `hypr/scripts/lock.sh`, which prefers it and falls back to hyprlock if the
  shell is not running. `SUPER+SHIFT+L` forces hyprlock directly.

## Principles that constrain all of the above

From `design.md §10` — worth re-reading before adding a surface:

1. Accent appears in exactly **three** places. A fourth is a redesign.
2. No warm hues, except terminal ANSI 1/3/9/11 where they are load-bearing
   semantics.
3. Everything on the 4px grid.
4. Weight never exceeds 400.
5. Never edit a generated file — edit the source in `design/`.
