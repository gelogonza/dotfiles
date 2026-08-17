#!/usr/bin/env python3
"""Generate every downstream token file from design/tokens.json.

The desktop has four consumers in three languages, none of which can import each
other: the Quickshell shell (QML), the SDDM login theme (QML, but a separate
import root that cannot see the shell's singleton), GTK/Waybar (CSS), and
Hyprland/hyprlock (hyprlang). This script keeps all four in lockstep from one
source so a colour change is a one-line edit.

Usage:  design/build-tokens.py [--check]

  --check  exit non-zero if any generated file is stale (for CI / pre-commit)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design" / "tokens.json"

BANNER = "GENERATED FILE — DO NOT EDIT. Source: design/tokens.json (run design/build-tokens.py)"


def strip_comments(node):
    """Drop $-prefixed annotation keys; they document the source, not the output."""
    if isinstance(node, dict):
        return {k: strip_comments(v) for k, v in node.items() if not k.startswith("$")}
    return node


def camel(name: str) -> str:
    """bg-0 -> bg0, accent-dim -> accentDim (hyphens are illegal in QML identifiers)."""
    head, *rest = name.split("-")
    out = head
    for part in rest:
        out += part if part.isdigit() else part.capitalize()

    # `onFoo` is how QML spells a handler for a signal named `foo`. A property
    # with that shape does not become a property — the engine tries to parse the
    # value as a script and the entire singleton fails to load, with an error
    # that points at the line but not at the cause.
    if re.fullmatch(r"on[A-Z].*", out):
        raise SystemExit(
            f"error: token '{name}' generates QML identifier '{out}', which QML "
            f"reads as a signal handler. Rename the token (e.g. 'accent-ink' "
            f"rather than 'on-accent')."
        )
    return out


def snake(name: str) -> str:
    """accent-dim -> accent_dim (hyprlang variables tolerate underscores, not hyphens)."""
    return name.replace("-", "_")


def qml_num(v) -> str:
    return str(v) if isinstance(v, int) else repr(float(v))


def qml_color(value: str) -> str:
    """QML parses hex colours as #aarrggbb; the token source uses CSS #rrggbbaa."""
    h = value.lstrip("#")
    if len(h) == 8:
        return f"#{h[6:8]}{h[0:6]}"
    return value


def hypr_color(value: str) -> tuple[str, str]:
    """Return (rgb-or-rgba form, explicit rgba form) for a hyprlang variable."""
    h = value.lstrip("#")
    if len(h) == 8:
        return f"rgba({h})", f"rgba({h})"
    return f"rgb({h})", f"rgba({h}ff)"


# --------------------------------------------------------------------------
# QML singleton
# --------------------------------------------------------------------------

def render_qml(t: dict) -> str:
    color, space, radius = t["color"], t["space"], t["radius"]
    typo, motion, mat = t["type"], t["motion"], t["material"]

    L: list[str] = [
        f"// {BANNER}",
        "pragma Singleton",
        "",
        "import QtQuick",
        "",
        "QtObject {",
        "    id: root",
        "",
        "    // Returns `c` at alpha `a`. Materials are defined as a base colour plus an",
        "    // opacity, so nearly every surface in the system goes through here.",
        "    function alpha(c, a) {",
        "        return Qt.rgba(c.r, c.g, c.b, a);",
        "    }",
        "",
        "    readonly property QtObject color: QtObject {",
    ]
    for k, v in color.items():
        L.append(f'        readonly property color {camel(k)}: "{qml_color(v)}"')
    L += ["    }", "", "    readonly property QtObject space: QtObject {"]
    for k, v in space.items():
        L.append(f"        readonly property int {k}: {v}")
    L += ["    }", "", "    readonly property QtObject radius: QtObject {"]
    for k, v in radius.items():
        L.append(f"        readonly property int {k}: {v}")
    L += [
        "    }",
        "",
        "    // Open tracking is part of the XMB feel. QML letterSpacing is in",
        "    // pixels, so it has to be derived from the size it is applied at.",
        "    function tracking(pixelSize) {",
        "        return pixelSize * root.typography.trackingEm;",
        "    }",
        "",
        "    readonly property QtObject typography: QtObject {",
        f'        readonly property string display: "{typo["display"]}"',
        "",
        "        // QML's font value type exposes `family` (one string) and has no",
        "        // `families` list, so per-glyph fallback is fontconfig's job, not",
        "        // ours. This list is here for the CSS tier, which can express it.",
        "        readonly property var families: ["
        + ", ".join(f'"{f}"' for f in typo["families"])
        + "]",
        "",
        f'        readonly property real trackingEm: {qml_num(typo["trackingEm"])}',
        "",
        "        readonly property QtObject size: QtObject {",
    ]
    for k, v in typo["size"].items():
        L.append(f"            readonly property int {k}: {v}")
    L += ["        }", "", "        readonly property QtObject weight: QtObject {"]
    for k, v in typo["weight"].items():
        L.append(f"            readonly property int {k}: {v}")
    L += ["        }", "    }", ""]

    w = t["weather"]
    fmt = t["format"]
    L += [
        "    // See design/tokens.json — this is off by default because turning it",
        "    // on means talking to a third-party server about where you are.",
        "    readonly property QtObject weather: QtObject {",
        f'        readonly property bool enabled: {"true" if w["enabled"] else "false"}',
        f'        readonly property string location: "{w["location"]}"',
        "    }",
        "",
        "    // Time and measurement formatting. One source for the four surfaces",
        "    // that show a clock, so they cannot disagree with each other.",
        "    readonly property QtObject format: QtObject {",
        f'        readonly property string clock: "{fmt["clock"]}"',
        f'        readonly property string units: "{fmt["units"]}"',
        "",
        "        // Ready to hand to Qt.formatDateTime. `AP` renders AM/PM, and `h`",
        "        // (not `hh`) drops the leading zero — 3:45 PM, not 03:45 PM.",
        '        readonly property string timePattern: clock === "24h" ? "HH:mm" : "h:mm AP"',
        "",
        '        readonly property bool imperial: units === "imperial"',
        '        readonly property string degree: imperial ? "°F" : "°C"',
        "    }",
        "",
        "    readonly property QtObject motion: QtObject {",
    ]

    e = motion["ease"]
    L += [
        "        // Feed straight into `easing.bezierCurve`. QML wants six values:",
        "        // the two control points plus the fixed (1,1) endpoint.",
        "        readonly property var easeBezier: ["
        + ", ".join(qml_num(x) for x in e)
        + ", 1.0, 1.0]",
        "",
        "        readonly property QtObject duration: QtObject {",
    ]
    for k, v in motion["duration"].items():
        L.append(f"            readonly property int {k}: {v}")
    L += [
        "        }",
        "",
        f'        readonly property int stagger: {motion["stagger"]}',
        "    }",
        "",
        "    readonly property QtObject material: QtObject {",
    ]

    # Paintable values derived from the raw numbers above, so components never
    # have to recombine a base colour with an opacity themselves.
    derived = {
        "chrome": [
            "// The brushed-metal gradient stops, and the hairline/shadow that frame them.",
            "readonly property color surfaceTop: root.alpha(root.color.bg1, surfaceOpacity)",
            "readonly property color surfaceBottom: root.alpha(Qt.darker(root.color.bg1, 1.0 + gradientDarken), surfaceOpacity)",
            "readonly property color stroke: root.alpha(root.color.border, strokeOpacity)",
            "// Built from `shade`, not bg-0. On the light palette bg-0 is the",
            "// lightest surface, so a shadow made from it would be invisible.",
            "readonly property color shadow: root.alpha(root.color.shade, shadowOpacity)",
        ],
        "glow": [
            "readonly property color tint: root.color.accent",
        ],
    }

    for group, values in mat.items():
        L.append(f"        readonly property QtObject {group}: QtObject {{")
        for k, v in values.items():
            kind = "int" if isinstance(v, int) else "real"
            L.append(f"            readonly property {kind} {k}: {qml_num(v)}")
        for line in derived.get(group, []):
            L.append(f"            {line}" if line.startswith("//") else f"            {line}")
        L.append("        }")
        L.append("")

    L += ["    }", "}", ""]
    return "\n".join(L)


def render_qmldir(singleton: str = "Tokens") -> str:
    # No `module` line: these are imported as plain directory imports
    # (`import "root:/Theme"` in the shell, `import "../Theme"` in the SDDM theme),
    # not as installed, identified QML modules.
    return f"# {BANNER}\nsingleton {singleton} 1.0 {singleton}.qml\n"


# --------------------------------------------------------------------------
# CSS
# --------------------------------------------------------------------------

def render_css(t: dict) -> str:
    e = t["motion"]["ease"]
    L = [f"/* {BANNER} */", "", ":root {"]

    L.append("  /* colour */")
    for k, v in t["color"].items():
        L.append(f"  --{k}: {v};")

    L.append("")
    L.append("  /* spacing — 4px grid */")
    for k, v in t["space"].items():
        L.append(f"  --space-{k}: {v}px;")

    L.append("")
    L.append("  /* radius */")
    for k, v in t["radius"].items():
        L.append(f"  --radius-{k}: {v}px;")

    L.append("")
    L.append("  /* type */")
    fams = ", ".join(f'"{f}"' for f in t["type"]["families"])
    L.append(f"  --font-display: {fams}, sans-serif;")
    for k, v in t["type"]["size"].items():
        L.append(f"  --text-{k}: {v}px;")
    for k, v in t["type"]["weight"].items():
        L.append(f"  --weight-{k}: {v};")
    L.append(f'  --tracking: {t["type"]["trackingEm"]}em;')

    L.append("")
    L.append("  /* motion */")
    L.append(f"  --ease: cubic-bezier({e[0]}, {e[1]}, {e[2]}, {e[3]});")
    for k, v in t["motion"]["duration"].items():
        L.append(f"  --dur-{k}: {v}ms;")
    L.append(f'  --stagger: {t["motion"]["stagger"]}ms;')

    L.append("")
    L.append("  /* chrome / reflection material */")
    for group, values in t["material"].items():
        for k, v in values.items():
            unit = "px" if k.endswith(("Radius", "OffsetY")) or k == "radius" else ""
            L.append(f"  --{group}-{k}: {v}{unit};")

    L += ["}", ""]
    return "\n".join(L)


# --------------------------------------------------------------------------
# VS Code
# --------------------------------------------------------------------------

def _mix(a: str, b: str, t: float) -> str:
    """Blend two #rrggbb colours. Used to derive editor chrome steps."""
    a, b = a.lstrip("#"), b.lstrip("#")
    out = []
    for i in (0, 2, 4):
        ca, cb = int(a[i:i + 2], 16), int(b[i:i + 2], 16)
        out.append(round(ca + (cb - ca) * t))
    return "#" + "".join(f"{v:02x}" for v in out)


def render_vscode(t: dict) -> str:
    """A VS Code colour theme built from the TERMINAL palette, not the UI one.

    The desktop chrome is light; the editor and the terminal are dark. That is
    deliberate rather than inconsistent — surfaces you work *in* are dark, the
    chrome you work *with* is light — and it means an editor split and a
    terminal split sitting side by side are the same colour.

    Syntax colours are the ANSI set, so a diff in the terminal and the same diff
    in the editor are literally the same greens and reds.

    Two rules this file has to honour that are easy to miss:

    * **Nothing here may reach into `color.*`.** The desktop accent (#3478c4)
      lives in exactly three places system-wide (design.md §3) and an editor
      badge is not one of them. Where the editor needs an accent — focus ring,
      cursor, active tab, badge — it uses ANSI bright blue, which is already in
      this palette. That also measures better: white on the desktop accent is
      4.54:1, editor-background ink on bright blue is 8.13:1.
    * **Every surface VS Code can paint has to be named.** Anything left unset
      falls back to the stock vs-dark greys, and a single `#3c3c3c` input box
      in a navy window is more obviously wrong than a slightly-off blue. The
      grouping below is by surface so gaps are visible at a glance.
    """
    term = t["terminal"]
    ansi = term["ansi"]

    bg = term["background"]          # #14293f
    fg = term["foreground"]
    black, red, green, yellow = ansi[0], ansi[1], ansi[2], ansi[3]
    blue, magenta, cyan, white = ansi[4], ansi[5], ansi[6], ansi[7]
    br_black, br_red, br_green, br_yellow = ansi[8], ansi[9], ansi[10], ansi[11]
    br_blue, br_magenta, br_cyan, br_white = ansi[12], ansi[13], ansi[14], ansi[15]

    deep = _mix(bg, "#000000", 0.35)      # sidebars, panels, title bar
    raised = _mix(bg, "#ffffff", 0.06)    # hovered rows, line highlight
    widget = _mix(bg, "#ffffff", 0.10)    # suggest/hover/palette surfaces
    line = _mix(bg, "#ffffff", 0.13)      # borders

    # ANSI bright-black is the terminal's "dim" slot, and at 2.69:1 on this
    # background it is fine for a shell prompt and far too quiet for the
    # comments you read for eight hours. Lifting it 35% toward the foreground
    # gives 4.93:1 — clears AA, still visibly subordinate to code (12.05:1).
    # Hierarchy by opacity, which is what design.md asks for; the raw slot is
    # kept for non-text furniture (indent guides, whitespace dots).
    muted = _mix(br_black, fg, 0.35)

    # Two more steps on the same dim ramp, both set by measurement:
    #   dim   — line numbers, the quietest text in the window. The raw ANSI
    #           slot measures 2.69:1 and is genuinely hard to scan at 13px;
    #           3.99:1 keeps them subordinate to comments (4.93:1) and legible.
    #   hint  — placeholder text. `muted` on the *raised* input surface is only
    #           4.12:1, because the surface it sits on is lighter than the
    #           editor. It needs its own step to clear AA there.
    dim = _mix(br_black, fg, 0.22)
    hint = _mix(br_black, fg, 0.45)

    accent = br_blue                 # the editor's accent, ANSI not desktop
    accent_ink = bg                  # what sits ON it

    colors = {
        # -- editor ------------------------------------------------------
        "editor.background": bg,
        "editor.foreground": fg,
        "editorLineNumber.foreground": dim,
        "editorLineNumber.activeForeground": accent,
        "editorCursor.foreground": accent,
        "editor.selectionBackground": accent + "3d",
        "editor.selectionHighlightBackground": accent + "1f",
        "editor.wordHighlightBackground": accent + "1f",
        "editor.wordHighlightStrongBackground": accent + "2e",
        "editor.findMatchBackground": yellow + "4d",
        "editor.findMatchHighlightBackground": yellow + "26",
        "editor.lineHighlightBackground": raised,
        "editor.foldBackground": raised,
        "editorIndentGuide.background1": line,
        "editorIndentGuide.activeBackground1": br_black,
        "editorWhitespace.foreground": br_black,
        "editorRuler.foreground": line,
        "editorBracketMatch.background": accent + "26",
        "editorBracketMatch.border": accent,
        "editorLink.activeForeground": accent,
        "editorInlayHint.background": raised,
        "editorInlayHint.foreground": muted,

        # -- editor gutter and rulers (git state at a glance) -------------
        "editorGutter.modifiedBackground": br_yellow,
        "editorGutter.addedBackground": br_green,
        "editorGutter.deletedBackground": br_red,
        "editorOverviewRuler.border": deep,
        "editorOverviewRuler.modifiedForeground": br_yellow,
        "editorOverviewRuler.addedForeground": br_green,
        "editorOverviewRuler.deletedForeground": br_red,
        "editorOverviewRuler.errorForeground": br_red,
        "editorOverviewRuler.warningForeground": br_yellow,
        "editorOverviewRuler.findMatchForeground": yellow,

        # -- diffs: the same greens and reds as `git diff` in the terminal -
        "diffEditor.insertedTextBackground": green + "22",
        "diffEditor.removedTextBackground": red + "22",
        "diffEditor.insertedLineBackground": green + "18",
        "diffEditor.removedLineBackground": red + "18",
        "diffEditor.diagonalFill": line,
        "diffEditorGutter.insertedLineBackground": green + "22",
        "diffEditorGutter.removedLineBackground": red + "22",

        # -- squiggles and problem state ---------------------------------
        "editorError.foreground": br_red,
        "editorWarning.foreground": br_yellow,
        "editorInfo.foreground": accent,
        "editorHint.foreground": muted,
        "problemsErrorIcon.foreground": br_red,
        "problemsWarningIcon.foreground": br_yellow,
        "problemsInfoIcon.foreground": accent,

        # -- minimap -----------------------------------------------------
        "minimap.background": bg,
        "minimap.findMatchHighlight": yellow,
        "minimap.selectionHighlight": accent,
        "minimapGutter.modifiedBackground": br_yellow,
        "minimapGutter.addedBackground": br_green,
        "minimapGutter.deletedBackground": br_red,
        "minimapSlider.background": br_black + "33",
        "minimapSlider.hoverBackground": br_black + "4d",
        "minimapSlider.activeBackground": br_black + "66",

        # -- side bar / activity bar --------------------------------------
        "sideBar.background": deep,
        "sideBar.foreground": white,
        "sideBar.border": deep,
        "sideBarSectionHeader.background": deep,
        "sideBarSectionHeader.foreground": muted,
        "sideBarSectionHeader.border": line,
        "sideBarTitle.foreground": accent,
        "activityBar.background": deep,
        "activityBar.foreground": accent,
        "activityBar.inactiveForeground": muted,
        "activityBar.border": deep,
        "activityBarBadge.background": accent,
        "activityBarBadge.foreground": accent_ink,

        # -- tabs ---------------------------------------------------------
        "editorGroupHeader.tabsBackground": deep,
        "editorGroupHeader.noTabsBackground": deep,
        "editorGroupHeader.tabsBorder": deep,
        "editorGroup.border": line,
        "editorGroup.dropBackground": accent + "26",
        "tab.activeBackground": bg,
        "tab.activeForeground": fg,
        "tab.inactiveBackground": deep,
        "tab.inactiveForeground": muted,
        "tab.hoverBackground": raised,
        "tab.unfocusedActiveBackground": bg,
        "tab.unfocusedActiveForeground": muted,
        "tab.activeBorderTop": accent,
        "tab.activeBorder": bg,
        "tab.border": deep,
        "breadcrumb.background": bg,
        "breadcrumb.foreground": muted,
        "breadcrumb.focusForeground": fg,
        "breadcrumbPicker.background": widget,

        # -- status bar / title bar ---------------------------------------
        "statusBar.background": deep,
        "statusBar.foreground": white,
        "statusBar.border": deep,
        "statusBar.noFolderBackground": deep,
        "statusBar.debuggingBackground": accent,
        "statusBar.debuggingForeground": accent_ink,
        "statusBarItem.hoverBackground": raised,
        "statusBarItem.remoteBackground": deep,
        "statusBarItem.remoteForeground": accent,
        "statusBarItem.errorBackground": deep,
        "statusBarItem.errorForeground": br_red,
        "statusBarItem.warningBackground": deep,
        "statusBarItem.warningForeground": br_yellow,
        "titleBar.activeBackground": deep,
        "titleBar.activeForeground": fg,
        "titleBar.inactiveBackground": deep,
        "titleBar.inactiveForeground": muted,
        "titleBar.border": deep,

        # -- panel / terminal ---------------------------------------------
        "panel.background": bg,
        "panel.border": line,
        "panelTitle.activeForeground": fg,
        "panelTitle.inactiveForeground": muted,
        "panelTitle.activeBorder": accent,
        "panelSection.border": line,
        "terminal.background": bg,
        "terminal.foreground": fg,
        "terminal.border": line,
        "terminalCursor.foreground": term["cursor"],
        "terminal.selectionBackground": term["selectionBackground"],
        "terminal.inactiveSelectionBackground": term["selectionBackground"] + "80",

        # -- widgets: palette, suggest, hover, peek -----------------------
        # All of these default to stock grey when unset. They are the surfaces
        # a command palette / autocomplete pops over the editor, so a grey one
        # is the single most visible way this theme can look unfinished.
        "widget.border": line,
        "widget.shadow": "#00000059",
        "editorWidget.background": widget,
        "editorWidget.foreground": fg,
        "editorWidget.border": line,
        "editorSuggestWidget.background": widget,
        "editorSuggestWidget.border": line,
        "editorSuggestWidget.foreground": fg,
        "editorSuggestWidget.selectedBackground": accent + "2e",
        "editorSuggestWidget.selectedForeground": fg,
        "editorSuggestWidget.highlightForeground": accent,
        "editorSuggestWidget.focusHighlightForeground": accent,
        "editorHoverWidget.background": widget,
        "editorHoverWidget.foreground": fg,
        "editorHoverWidget.border": line,
        "editorHoverWidget.statusBarBackground": raised,
        "quickInput.background": widget,
        "quickInput.foreground": fg,
        "quickInputTitle.background": raised,
        "quickInputList.focusBackground": accent + "2e",
        "quickInputList.focusForeground": fg,
        "pickerGroup.foreground": accent,
        "pickerGroup.border": line,
        "peekView.border": accent,
        "peekViewEditor.background": bg,
        "peekViewEditor.matchHighlightBackground": yellow + "4d",
        "peekViewResult.background": deep,
        "peekViewResult.lineForeground": muted,
        "peekViewResult.fileForeground": accent,
        "peekViewResult.selectionBackground": accent + "2e",
        "peekViewResult.matchHighlightBackground": yellow + "4d",
        "peekViewTitle.background": deep,
        "peekViewTitleLabel.foreground": fg,
        "peekViewTitleDescription.foreground": muted,

        # -- inputs, dropdowns, buttons, checkboxes -----------------------
        # Verified gap: with these unset an input field renders #3c3c3c —
        # measured as 1.6% of a stock window, and unmistakably not this palette.
        "input.background": raised,
        "input.foreground": fg,
        "input.border": line,
        "input.placeholderForeground": hint,
        "inputOption.activeBackground": accent + "2e",
        "inputOption.activeForeground": fg,
        "inputOption.activeBorder": accent,
        "inputValidation.errorBackground": deep,
        "inputValidation.errorForeground": fg,
        "inputValidation.errorBorder": br_red,
        "inputValidation.warningBackground": deep,
        "inputValidation.warningForeground": fg,
        "inputValidation.warningBorder": br_yellow,
        "inputValidation.infoBackground": deep,
        "inputValidation.infoForeground": fg,
        "inputValidation.infoBorder": accent,
        "dropdown.background": widget,
        "dropdown.listBackground": widget,
        "dropdown.foreground": fg,
        "dropdown.border": line,
        "checkbox.background": raised,
        "checkbox.foreground": fg,
        "checkbox.border": line,
        "button.background": accent,
        "button.foreground": accent_ink,
        "button.hoverBackground": br_cyan,
        "button.secondaryBackground": raised,
        "button.secondaryForeground": fg,
        "button.secondaryHoverBackground": widget,
        "badge.background": accent,
        "badge.foreground": accent_ink,
        "progressBar.background": accent,
        "focusBorder": accent,
        "contrastBorder": "#00000000",
        "contrastActiveBorder": "#00000000",

        # -- lists and trees ----------------------------------------------
        "list.activeSelectionBackground": raised,
        "list.activeSelectionForeground": fg,
        "list.inactiveSelectionBackground": raised,
        "list.inactiveSelectionForeground": fg,
        "list.hoverBackground": raised,
        "list.hoverForeground": fg,
        "list.focusBackground": accent + "2e",
        "list.focusForeground": fg,
        "list.focusOutline": accent + "00",
        "list.highlightForeground": accent,
        "list.errorForeground": br_red,
        "list.warningForeground": br_yellow,
        "tree.indentGuidesStroke": line,
        "listFilterWidget.background": widget,
        "listFilterWidget.outline": accent,
        "listFilterWidget.noMatchesOutline": br_red,

        # -- menus --------------------------------------------------------
        "menu.background": widget,
        "menu.foreground": fg,
        "menu.border": line,
        "menu.separatorBackground": line,
        "menu.selectionBackground": accent + "2e",
        "menu.selectionForeground": fg,
        "menubar.selectionBackground": raised,
        "menubar.selectionForeground": fg,

        # -- notifications ------------------------------------------------
        "notificationCenter.border": line,
        "notificationCenterHeader.background": deep,
        "notificationCenterHeader.foreground": muted,
        "notifications.background": widget,
        "notifications.foreground": fg,
        "notifications.border": line,
        "notificationLink.foreground": accent,
        "notificationsErrorIcon.foreground": br_red,
        "notificationsWarningIcon.foreground": br_yellow,
        "notificationsInfoIcon.foreground": accent,

        # -- scrollbars ---------------------------------------------------
        "scrollbar.shadow": "#00000059",
        "scrollbarSlider.background": br_black + "55",
        "scrollbarSlider.hoverBackground": br_black + "80",
        "scrollbarSlider.activeBackground": br_black + "aa",

        # -- source control -----------------------------------------------
        "gitDecoration.modifiedResourceForeground": br_yellow,
        "gitDecoration.addedResourceForeground": br_green,
        "gitDecoration.deletedResourceForeground": br_red,
        "gitDecoration.untrackedResourceForeground": br_green,
        "gitDecoration.ignoredResourceForeground": br_black,
        "gitDecoration.conflictingResourceForeground": br_magenta,
        "gitDecoration.stageModifiedResourceForeground": br_yellow,
        "gitDecoration.stageDeletedResourceForeground": br_red,
        "gitDecoration.submoduleResourceForeground": br_cyan,

        # -- misc chrome ---------------------------------------------------
        "settings.headerForeground": fg,
        "settings.modifiedItemIndicator": accent,
        "keybindingLabel.background": raised,
        "keybindingLabel.foreground": fg,
        "keybindingLabel.border": line,
        "keybindingLabel.bottomBorder": line,
        "textLink.foreground": accent,
        "textLink.activeForeground": br_cyan,
        "textCodeBlock.background": raised,
        "textBlockQuote.background": raised,
        "textBlockQuote.border": accent,
        "textPreformat.foreground": br_cyan,
        "textSeparator.foreground": line,
        "descriptionForeground": muted,
        "errorForeground": br_red,
        "icon.foreground": white,
        "toolbar.hoverBackground": raised,
        "toolbar.activeBackground": widget,
        "sash.hoverBorder": accent,
        "selection.background": accent + "3d",
        "debugToolBar.background": widget,
        "debugToolBar.border": line,
        "editorStickyScroll.background": deep,
        "editorStickyScrollHover.background": raised,
        "welcomePage.background": bg,
        "welcomePage.tileBackground": deep,
        "welcomePage.tileHoverBackground": raised,
        "walkThrough.embeddedEditorBackground": deep,
    }

    # The full 16-colour ANSI set, so the integrated terminal matches ghostty.
    names = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
    for i, n in enumerate(names):
        colors[f"terminal.ansi{n}"] = ansi[i]
        colors[f"terminal.ansiBright{n}"] = ansi[i + 8]

    scopes = [
        ("Comment", ["comment", "punctuation.definition.comment"], muted, "italic"),
        ("String", ["string", "string.quoted", "constant.other.symbol"], green, ""),
        ("Number / constant", ["constant.numeric", "constant.language",
                               "constant.character.escape"], yellow, ""),
        ("Keyword", ["keyword", "storage.type", "storage.modifier",
                     "keyword.control"], magenta, ""),
        ("Operator", ["keyword.operator", "punctuation"], white, ""),
        ("Function", ["entity.name.function", "support.function",
                      "meta.function-call"], br_blue, ""),
        ("Type / class", ["entity.name.type", "entity.name.class",
                          "support.type", "support.class"], cyan, ""),
        ("Variable", ["variable", "meta.definition.variable"], fg, ""),
        ("Parameter", ["variable.parameter"], br_cyan, ""),
        ("Property", ["variable.other.property", "meta.object-literal.key",
                      "support.type.property-name"], br_cyan, ""),
        ("Tag", ["entity.name.tag"], red, ""),
        ("Attribute", ["entity.other.attribute-name"], br_yellow, ""),
        ("Invalid", ["invalid"], br_red, ""),
        # Markdown and diffs are read in this editor as often as code is, and
        # both fall back to near-invisible defaults without an explicit scope.
        ("Markup heading", ["markup.heading", "entity.name.section"], accent, ""),
        ("Markup emphasis", ["markup.italic"], fg, "italic"),
        ("Markup strong", ["markup.bold"], fg, "bold"),
        ("Markup link", ["markup.underline.link", "string.other.link"], br_cyan, ""),
        ("Markup code", ["markup.inline.raw", "markup.fenced_code"], br_cyan, ""),
        ("Diff inserted", ["markup.inserted"], br_green, ""),
        ("Diff deleted", ["markup.deleted"], br_red, ""),
        ("Diff changed", ["markup.changed"], br_yellow, ""),
    ]

    token_colors = []
    for name, scope, colour, style in scopes:
        settings = {"foreground": colour}
        if style:
            settings["fontStyle"] = style
        token_colors.append({"name": name, "scope": scope, "settings": settings})

    theme = {
        "$schema": "vscode://schemas/color-theme",
        "name": "gelo XMB",
        "type": "dark",
        "semanticHighlighting": True,
        "colors": colors,
        "tokenColors": token_colors,
    }

    return ("// " + BANNER + "\n"
            + json.dumps(theme, indent=2) + "\n")


def render_vscode_manifest(t: dict) -> str:
    manifest = {
        "name": "gelo-xmb",
        "displayName": "gelo XMB",
        "description": "Generated from design/tokens.json — do not edit by hand.",
        "version": "1.0.0",
        "publisher": "gelo",
        "engines": {"vscode": "^1.70.0"},
        "categories": ["Themes"],
        "contributes": {
            "themes": [{
                "label": "gelo XMB",
                "uiTheme": "vs-dark",
                "path": "./themes/gelo-xmb-color-theme.json",
            }]
        },
    }
    return json.dumps(manifest, indent=2) + "\n"


# --------------------------------------------------------------------------
# Spotify (spicetify)
# --------------------------------------------------------------------------

def render_spicetify(t: dict) -> str:
    """A spicetify `color.ini`, from the TERMINAL block for the same reason the
    editor is (§8c): Spotify is a full application window sitting next to the
    terminal and the editor, and all three being one colour is the point.

    This file is the **whole theme on its own** — `user.css` next to it adds the
    material language (chrome, glow) but is strictly optional. If a Spotify
    update breaks the stylesheet, delete it and re-apply: what is left is a
    complete, correct theme, because a `color.ini` only feeds spicetify's own
    `--spice-*` variables, which is the part of the contract Spotify updates are
    least likely to move.

    Restore before debugging anything here — see `docs/spotify.md`.
    """
    term = t["terminal"]
    ansi = term["ansi"]

    bg = term["background"]
    fg = term["foreground"]
    br_black, br_red = ansi[8], ansi[9]
    br_blue, br_cyan = ansi[12], ansi[14]

    deep = _mix(bg, "#000000", 0.35)      # sidebar, player bar
    raised = _mix(bg, "#ffffff", 0.06)    # cards, hover
    widget = _mix(bg, "#ffffff", 0.10)    # elevated hover
    line = _mix(bg, "#ffffff", 0.13)      # progress/scroll troughs
    shadow = _mix(bg, "#000000", 0.65)

    # One subtext value rather than the editor's three-step ramp: Spotify puts
    # secondary text on three surfaces (main, sidebar, card) and the card is the
    # lightest, so the step is set by that worst case. `muted` (the editor's
    # value) is only 4.12:1 on a card; this clears AA on all three — 5.78 main,
    # 6.80 sidebar, 4.83 card.
    subtext = _mix(br_black, fg, 0.45)

    accent = br_blue                      # ANSI, not color.accent — see §8c
    accent_hot = br_cyan                  # hover / active state

    # spicetify wants bare hex, no leading '#'.
    def h(v: str) -> str:
        return v.lstrip("#")[:6]

    scheme = {
        "text": fg,
        "subtext": subtext,
        "main": bg,
        "main-elevated": raised,
        "highlight": raised,
        "highlight-elevated": widget,
        "card": raised,
        "sidebar": deep,
        # `sidebar-alt` and `selected-row` are standard spicetify keys that
        # Spotify 1.2.95 does not reference at all (checked against every
        # stylesheet in Apps/xpui — the other 17 keys here are live). They are
        # kept because they cost nothing and Spotify moves these around between
        # releases; they are simply not doing anything today.
        "sidebar-alt": deep,
        "player": deep,
        "shadow": shadow,
        "selected-row": accent,
        "button": accent,
        "button-active": accent_hot,
        # The unfilled half of the progress and volume bars. It sits on
        # `player`, where it measures 1.77:1 — deliberately low. It is a trough,
        # not text, and the filled half next to it is the thing being read.
        "button-disabled": line,
        "tab-active": raised,
        "notification": accent,
        "notification-error": br_red,
        "misc": subtext,
    }

    L = [f"; {BANNER}", "", "[base]"]
    width = max(len(k) for k in scheme)
    for k, v in scheme.items():
        L.append(f"{k.ljust(width)} = {h(v)}")
    return "\n".join(L) + "\n"


def render_spicetify_css(t: dict) -> str:
    """The XMB material language applied to Spotify: chrome, glow, reflection.

    This is the one stylesheet in the system that targets an app we do not
    control, and it is written to fail *safely*:

    * **Colour comes from `var(--spice-*)`, never a literal.** spicetify already
      emits every key in `color.ini` as both a hex and an `--spice-rgb-*`
      triplet, so this file inherits the palette automatically and a token
      change needs no edit here.
    * **Visual properties only** — background, box-shadow, border, filter,
      box-reflect. Nothing that participates in layout. A selector that stops
      matching then costs a lost effect, not a broken window.
    * **Selectors are `data-testid` or Spotify's own semantic class names**
      (`.x-progressBar-fillColor`, `.main-trackList-*`). Both survive releases
      far better than the hashed utility classes around them.

    If a Spotify update breaks something, delete this file and re-apply — the
    `color.ini` alone is a complete, working theme. See `docs/spotify.md`.
    """
    mat = t["material"]
    ch, glow, refl = mat["chrome"], mat["glow"], mat["reflection"]
    motion, radius = t["motion"], t["radius"]

    e = motion["ease"]
    ease = f"cubic-bezier({e[0]}, {e[1]}, {e[2]}, {e[3]})"
    fast = f'{motion["duration"]["fast"]}ms'
    base = f'{motion["duration"]["base"]}ms'

    ext = glow["extent"]
    hov, act = glow["hoverOpacity"], glow["activeOpacity"]

    def bloom(var: str, o: float) -> str:
        """design.md §5: concentric falloff, not one gaussian. Three stops of
        box-shadow approximate the quadratic ramp the QML component draws."""
        return (f"0 0 {round(ext * 0.35)}px rgba(var(--spice-rgb-{var}), {round(o, 3)}), "
                f"0 0 {round(ext * 0.7)}px rgba(var(--spice-rgb-{var}), {round(o * 0.45, 3)}), "
                f"0 0 {ext}px rgba(var(--spice-rgb-{var}), {round(o * 0.2, 3)})")

    dark = round(ch["gradientDarken"] * 100)
    lift = round(ch["gradientDarken"] * 100 / 2)

    return f"""/* {BANNER} */

/* ------------------------------------------------------------------ *
 * Chrome — the player bar reads as brushed metal. Measured top-to-bottom
 * after applying: #14212f -> #0c1926, which is present without reading
 * as a gradient. A flat fill reads as paint; an obvious ramp reads as
 * 2000s web design.
 * ------------------------------------------------------------------ */

[data-testid="now-playing-bar"] {{
  background: linear-gradient(180deg,
      color-mix(in srgb, var(--spice-player), #fff {lift}%) 0%,
      color-mix(in srgb, var(--spice-player), #000 {dark}%) 100%) !important;
  border-top: 1px solid rgba(var(--spice-rgb-button), {ch["strokeOpacity"] * 0.22:.3f});
  box-shadow: 0 -{ch["shadowOffsetY"]}px {ch["shadowRadius"]}px
              rgba(var(--spice-rgb-shadow), {ch["shadowOpacity"]});
}}

/* ------------------------------------------------------------------ *
 * Glow — selection blooms, it does not get boxed. The single most
 * identifiable trait of the reference, and how the accent survives
 * being an accent instead of becoming a fill.
 * ------------------------------------------------------------------ */

.x-progressBar-fillColor,
.x-progressBar-progressFillColor {{
  background-color: var(--spice-button) !important;
  box-shadow: {bloom("button", act)};
}}

.x-progressBar-progressBarBg {{
  background-color: rgba(var(--spice-rgb-button-disabled), 0.55) !important;
}}

.progress-bar__slider,
.x-progressBar-sliderArea .progress-bar__slider {{
  background-color: var(--spice-button) !important;
  box-shadow: {bloom("button", act)};
}}

/* The play button stays white, and that is not a gap.
 *
 * It is an Encore control with colorSet="invertedLight", and spicetify's
 * replace_colors has already rewired that set to our palette
 * (`--background-base: var(--spice-text)`). It was following the theme all
 * along — via `text`, which is white, because Spotify deliberately inverts
 * its primary transport control.
 *
 * Two ways to force it accent were tried and both rejected:
 *   1. `background-color: ... !important` — does not win; the circle is
 *      painted by a hashed styled-components class, not by the testid element.
 *   2. Overriding Encore's colour-set variables on the button — same reason.
 * Reaching the real element means selecting on a hashed class, which is
 * exactly the fragility this stylesheet exists to avoid.
 *
 * So: light the button instead of repainting it. A white source inside an
 * accent bloom is closer to the reference than a blue disc anyway — the
 * reference glows things, it does not tint them. */
[data-testid="control-button-playpause"] {{
  border-radius: 50%;
  box-shadow: {bloom("button", act * 0.5)};
  transition: box-shadow {fast} {ease};
}}

[data-testid="control-button-playpause"]:hover {{
  box-shadow: {bloom("button", act)};
}}

/* Library rows and tracklist rows bloom on hover rather than filling.
   Radius stays fixed — corner-radius-on-interaction was the old glass
   affordance; here the affordance is the glow. */
.main-yourLibraryX-listItem:hover,
.main-trackList-trackListRow:hover {{
  border-radius: {radius["sm"]}px;
  box-shadow: {bloom("button", hov)};
  transition: box-shadow {base} {ease};
}}

.main-trackList-selected,
.main-yourLibraryX-listItem[aria-current="true"] {{
  border-radius: {radius["sm"]}px;
  box-shadow: {bloom("button", act * 0.55)};
}}

/* ------------------------------------------------------------------ *
 * The cover art, lit rather than mirrored.
 *
 * Reflection.qml was tried here first and does not fit: the player bar
 * gives the art ~16px of clearance before the window edge, so a
 * `-webkit-box-reflect` mirror is clipped to nothing. Making room means
 * changing layout, and layout is exactly what this file does not touch
 * in an app that updates itself.
 *
 * A bloom behind the art carries the same "floating, not pasted on"
 * read and needs no space at all — it grows into the chrome instead of
 * below it.
 * ------------------------------------------------------------------ */

[data-testid="now-playing-widget"] [data-testid="cover-art-image"] {{
  border-radius: {radius["sm"]}px;
  box-shadow: 0 0 {round(ext * 0.6)}px rgba(var(--spice-rgb-button), {round(refl["opacity"] * 1.6, 3)}),
              0 0 {ext * 2}px rgba(var(--spice-rgb-button), {round(refl["opacity"] * 0.7, 3)});
  transition: box-shadow {base} {ease};
}}

[data-testid="now-playing-widget"]:hover [data-testid="cover-art-image"] {{
  box-shadow: {bloom("button", hov)};
}}

/* ------------------------------------------------------------------ *
 * Hairlines. The material is carried by the edge and the glow, so the
 * edge has to actually be there.
 * ------------------------------------------------------------------ */

.main-card-card,
[data-testid="card-container"] {{
  border: 1px solid rgba(var(--spice-rgb-button), 0.10);
  border-radius: {radius["sm"]}px;
  transition: box-shadow {base} {ease}, border-color {base} {ease};
}}

.main-card-card:hover,
[data-testid="card-container"]:hover {{
  border-color: rgba(var(--spice-rgb-button), 0.28);
  box-shadow: {bloom("button", hov)};
}}
"""


def _glsl_es(src: str) -> str:
    """Retarget `design/shaders/xmb.frag` from Qt 6 GLSL to WebGL2 (GLSL ES 3.00).

    The *body* is untouched — this rewrites only the header, so there is still
    exactly one authored copy of the wave field and the web version cannot
    drift from the one on the wallpaper. Three mechanical differences:

    * Qt wants `#version 440` and a `layout(std140) uniform buf { … }` block;
      WebGL2 wants `#version 300 es`, a precision qualifier, and loose uniforms.
    * `layout(location = …)` qualifiers on in/out are not allowed on a fragment
      shader's varyings in ES.
    * `qt_Matrix` / `qt_Opacity` do not exist here. `qt_Opacity` is redeclared as
      a constant so the body's final multiply still compiles unchanged.
    """
    body = src[src.index("};", src.index("uniform buf")) + 2:]

    uniforms = "\n".join(f"uniform {d};" for d in [
        "float time", "vec2 resolution",
        "vec4 colorBase", "vec4 colorMid", "vec4 colorHigh",
        "vec4 colorEdge", "vec4 colorLine", "vec4 colorAccent",
        "float rippleSpeed", "float rippleWidth", "float rippleAmplitude",
        "vec4 rippleA", "vec4 rippleB", "vec4 rippleC", "vec4 rippleD",
    ])

    return ("#version 300 es\n"
            "precision highp float;\n\n"
            "// Retargeted from design/shaders/xmb.frag by design/build-tokens.py.\n"
            "// Edit the .frag, never this string.\n\n"
            "in vec2 qt_TexCoord0;\n"
            "out vec4 fragColor;\n\n"
            f"{uniforms}\n\n"
            "const float qt_Opacity = 1.0;\n"
            + body)


def render_spicetify_js(t: dict) -> str:
    """Motion: the XMB wave field, behind Spotify, rippling on the beat — plus a
    live control panel for the handful of values worth tuning by eye.

    The system's thesis about motion is that it lives in a field *behind* the
    interface rather than in the interface (design.md §7). Animating Spotify's
    own widgets would contradict that; running the actual wallpaper shader
    behind it does not. On the desktop `Services/Ripples.qml` carries
    interaction points into that field. Here the same four slots carry **beats**.

    This is the third and most optional layer. `color.ini` is the theme,
    `user.css` is the material, this is the motion — and it injects its own
    transparency CSS, so deleting the file removes the canvas *and* the
    transparency together and leaves a correct static theme behind.

    **On the control panel and the single source of truth.** `tokens.json` is
    still it. The panel does not invent colours; it scales values that are
    already parameters (field brightness, scrim, panel opacity, reactivity,
    drift rate) and stores the offsets in Spotify's LocalStorage, per machine.
    Its real job is to let a value be found by eye on the live thing and then
    *moved into the token source* — which is why it can copy the current
    settings to the clipboard. Defaults come from `tokens.json`, and a reset
    returns to them exactly.

    Two deliberate departures from the wallpaper:

    * **A dark field ramp.** `field-*` is tuned for the light desktop; behind a
      dark Spotify it would be a lightbox. This ramp is derived from the
      terminal block, like everything else dark in the system.
    * **It stops when hidden.** The wallpaper cannot — wlr-layer-shell exposes
      no occlusion signal — but a web page gets `visibilitychange` for free.
    """
    term = t["terminal"]
    ansi = term["ansi"]
    rip = t["material"]["ripple"]
    mat = t["material"]
    bg = term["background"]

    frag = _glsl_es((ROOT / "design/shaders/xmb.frag").read_text())

    _h = bg.lstrip("#")
    scrim_rgb = ", ".join(str(int(_h[i:i + 2], 16)) for i in (0, 2, 4))
    sub_on_field = _mix(ansi[8], term["foreground"], 0.60)

    def rgba(hex_: str) -> str:
        h = hex_.lstrip("#")
        return "[" + ", ".join(f"{int(h[i:i+2], 16) / 255:.4f}" for i in (0, 2, 4)) + ", 1.0]"

    # Dimmer than the wallpaper's ramp, and not by taste: the wallpaper sits
    # behind nothing, this sits behind text. Measured by isolating the pixels
    # that move between two frames, the field's bright end at full ANSI bright
    # blue put secondary text at 3.21:1 — below AA and a regression on the flat
    # 5.78:1 it replaced. Primary text was never at risk; subtext sets the
    # ceiling here.
    base = _mix(bg, "#000000", 0.45)
    field = {
        "colorBase": base,
        "colorMid": bg,
        "colorHigh": _mix(bg, "#ffffff", 0.06),
        "colorEdge": _mix(bg, "#ffffff", 0.11),
        # The filaments ADD (xmb.frag tone section), so their brightness sets
        # the field's bright end directly. This is what `fieldGain` scales.
        "colorLine": _mix(ansi[12], base, 0.55),
        "colorAccent": _mix(ansi[14], base, 0.30),
    }
    field_js = ",\n    ".join(f"{k}: {rgba(v)}" for k, v in field.items())

    # The surface ramp, so the chrome can be recoloured by the same pipeline
    # as the field instead of being pinned to the token navy.
    surf = {
        "main": bg,
        "deep": _mix(bg, "#000000", 0.35),
        "raised": _mix(bg, "#ffffff", 0.06),
    }
    surf_js = ",\n    ".join(f"{k}: {rgba(v)}" for k, v in surf.items())

    e = t["motion"]["ease"]
    tpl = _SPICETIFY_JS
    for key, val in {
        "__BANNER__": BANNER,
        "__FIELD__": field_js,
        "__SURF__": surf_js,
        "__RSPEED__": str(rip["speed"]),
        "__RWIDTH__": str(rip["width"]),
        "__RAMP__": str(rip["amplitude"]),
        "__RSLOTS__": str(rip["maxConcurrent"]),
        "__SCRIM_RGB__": scrim_rgb,
        "__SUBFIELD__": sub_on_field,
        "__EASE__": f"cubic-bezier({e[0]}, {e[1]}, {e[2]}, {e[3]})",
        "__DUR__": str(t["motion"]["duration"]["fast"]),
        "__RADIUS__": str(t["radius"]["sm"]),
        "__GLOWEXT__": str(mat["glow"]["extent"]),
        "__FRAG__": json.dumps(frag),
    }.items():
        tpl = tpl.replace(key, val)
    return tpl


# Kept out of the function body so the JavaScript does not have to survive
# f-string brace doubling, which is how a template this size acquires bugs.
_SITE_CSS = r'''
  :root {
    --bg-0: __BG0__; --bg-1: __BG1__; --bg-2: __BG2__; --border: __BORDER__;
    --text-1: __TEXT1__; --text-2: __TEXT2__; --accent: __ACCENT__;
    --shade: __SHADE__;
    --ease: __EASE__; --dur: __DUR_BASE__ms;
    --r: __RADIUS_SM__px; --gap: __SPACE_LG__px;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: calc(var(--gap) * 2);
    background: var(--bg-0); color: var(--text-1);
    font-family: __FAMILY__, system-ui, sans-serif;
    font-weight: 300; letter-spacing: __TRACK__em;
    line-height: 1.5;
  }
  main { max-width: 1080px; margin: 0 auto; }
  h1 { font-size: 34px; font-weight: 400; margin: 0 0 4px; }
  h2 {
    font-size: 15px; font-weight: 400; margin: calc(var(--gap) * 2.5) 0 var(--gap);
    padding-bottom: 8px; border-bottom: 1px solid var(--border);
    color: var(--text-2); text-transform: lowercase;
  }
  .lede { color: var(--text-2); margin: 0 0 4px; max-width: 62ch; }
  code { font-family: ui-monospace, monospace; font-size: 12px; }

  /* The chrome material, described by the page and used by it. */
  .card {
    background: linear-gradient(180deg, var(--bg-1) 0%,
      color-mix(in srgb, var(--bg-1), #000 __CHROME_DARKEN__%) 100%);
    border: 1px solid var(--border); border-radius: var(--r);
    box-shadow: 0 6px __SHADOW_R__px color-mix(in srgb, var(--shade) 22%, transparent);
    padding: var(--gap);
  }

  .grid { display: flex; flex-wrap: wrap; gap: 12px; }
  .sw { margin: 0; width: 132px; }
  .chip {
    height: 56px; border-radius: var(--r); border: 1px solid var(--border);
    transition: transform var(--dur) var(--ease);
  }
  .sw:hover .chip { transform: translateY(-3px); }
  .chip.r { background: var(--accent); }
  figcaption { display: flex; flex-direction: column; margin-top: 6px; font-size: 12px; }
  figcaption span { color: var(--text-2); }
  figcaption em { color: var(--text-2); font-style: normal; font-size: 11px; }

  .ansi-row { display: flex; border-radius: var(--r); overflow: hidden;
              border: 1px solid var(--border); }
  .ansi { flex: 1; height: 40px; }

  table { border-collapse: collapse; width: 100%; font-size: 13px; }
  th, td { text-align: left; padding: 7px 10px; border-bottom: 1px solid var(--border); }
  th { color: var(--text-2); font-weight: 400; font-size: 12px; }
  td.num { font-family: ui-monospace, monospace; text-align: right; }
  tr.fail td { color: #b3261e; }
  .dot { display: inline-block; width: 13px; height: 13px; border-radius: 3px;
         border: 1px solid var(--border); vertical-align: middle; margin-right: 3px; }

  .spec { margin: 6px 0; }
  .bar { display: flex; align-items: center; gap: 10px; margin: 5px 0; font-size: 12px; }
  .bar span { display: block; height: 12px; background: var(--accent); border-radius: 2px; }
  .bar em { color: var(--text-2); font-style: normal; }

  .mo { display: flex; align-items: center; gap: 10px; margin: 8px 0; font-size: 12px; }
  .mo em { color: var(--text-2); font-style: normal; }
  .ball {
    width: 14px; height: 14px; border-radius: 50%; background: var(--accent);
    animation-name: slide; animation-timing-function: var(--ease);
    animation-iteration-count: infinite; animation-direction: alternate;
  }
  @keyframes slide { to { transform: translateX(210px); } }

  .term { background: __TERM_BG__; color: __TERM_FG__; border-radius: var(--r);
          padding: var(--gap); font-family: ui-monospace, monospace; font-size: 13px; }
  footer { margin-top: calc(var(--gap) * 3); color: var(--text-2); font-size: 12px; }
  @media (prefers-reduced-motion: reduce) { .ball { animation: none; } }

  nav { max-width: 1080px; margin: 0 auto calc(var(--gap) * 1.5); display: flex;
        gap: var(--gap); flex-wrap: wrap; }
  nav a { color: var(--text-2); text-decoration: none; font-size: 13px;
          padding-bottom: 3px; border-bottom: 1px solid transparent;
          transition: color var(--dur) var(--ease), border-color var(--dur) var(--ease); }
  nav a:hover { color: var(--text-1); }
  nav a.on { color: var(--text-1); border-bottom-color: var(--accent); }
  .cards { display: grid; gap: 12px; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
           margin-bottom: calc(var(--gap) * 1.5); }
  .case { display: block; text-decoration: none; color: inherit; padding: var(--gap);
          border: 1px solid var(--border); border-radius: var(--r);
          background: var(--bg-1);
          transition: transform var(--dur) var(--ease), box-shadow var(--dur) var(--ease); }
  .case:hover { transform: translateY(-2px);
                box-shadow: 0 6px 24px color-mix(in srgb, var(--shade) 20%, transparent); }
  .case h3 { margin: 0 0 6px; font-size: 14px; font-weight: 400; }
  .case p { margin: 0; font-size: 13px; color: var(--text-2); }
  pre.code { background: __TERM_BG__; color: __TERM_FG__; padding: var(--gap);
             border-radius: var(--r); overflow-x: auto; font-size: 12.5px; line-height: 1.5; }
  .big { font-size: 22px; margin: 0; }
  hr { border: 0; border-top: 1px solid var(--border); margin: 12px 0; }
  p { max-width: 68ch; }
'''


_SPICETIFY_JS = r"""// __BANNER__
//
// The XMB wave field, behind Spotify, rippling on the beat.
// Settings live in the profile menu ("XMB field"), or Ctrl+Alt+X.
// Not Ctrl+Shift+X: that is Spotify's Connect panel, and binding it
// opened both at once.
// Delete this file and re-apply to drop back to the static theme.

(function () {
  "use strict";

  var FIELD = {
    __FIELD__
  };
  var SURF = {
    __SURF__
  };
  var RIPPLE = { speed: __RSPEED__, width: __RWIDTH__, amplitude: __RAMP__, slots: __RSLOTS__ };

  // The palette's own hue, measured off ANSI bright blue. "Cool lock" pulls any
  // album hue back toward this, which is what keeps an album-tinted field
  // inside the system instead of turning it into whatever the cover art is.
  var PALETTE_HUE = 207.5;

  var BASE_RATE = 0.16;
  var FPS_CAP = 60;              // the surge waits up to a frame to render
  var KEY = "gelo-xmb-field";

  // Every default is the value the token source produces. Reset returns here.
  var DEFAULTS = {
    fieldGain: 1, sat: 1, tint: 0.65,
    scrim: 0.68, panel: 0.88, ui: 1,
    reactivity: 1, rate: 1, spin: 14, lead: 0.12,
    enabled: true, coolLock: true, turntable: true, waveform: true,
    // Colour SOURCE, not a colour. "tokens" is design/tokens.json and is the
    // default, so the system's palette is what you get until you ask for
    // something else. "custom" uses customColor; "album" follows the cover.
    colorMode: "tokens",
    customColor: "#8cc6f7",
    // What the chrome does with the chosen colour. "tinted" recolours the
    // surfaces and accents through the same pipeline as the field; "neutral"
    // drops them to plain black at the UI alpha, so the album shows through
    // without colouring the furniture.
    surface: "tinted"
  };
  var CFG = load();
  var ALBUM = null;            // {h, s, hex} from the current cover, or null

  function load() {
    var out = {};
    for (var k in DEFAULTS) out[k] = DEFAULTS[k];
    try {
      var raw = window.Spicetify && Spicetify.LocalStorage
        ? Spicetify.LocalStorage.get(KEY) : localStorage.getItem(KEY);
      if (raw) {
        var got = JSON.parse(raw);
        for (var j in DEFAULTS) if (typeof got[j] === typeof DEFAULTS[j]) out[j] = got[j];
      }
    } catch (e) { /* corrupt or absent: defaults are correct */ }
    return out;
  }

  function save() {
    try {
      var raw = JSON.stringify(CFG);
      if (window.Spicetify && Spicetify.LocalStorage) Spicetify.LocalStorage.set(KEY, raw);
      else localStorage.setItem(KEY, raw);
    } catch (e) { /* non-fatal: settings simply do not persist */ }
  }

  var gl = null, U = null, canvas = null, frame = 0;

  // ------------------------------------------------------------------
  // Colour.
  //
  // Everything here rotates HUE and scales SATURATION, then restores the
  // original WCAG relative luminance. That is load-bearing rather than tidy:
  // the field's contrast against text was measured once (design.md 8d), and
  // those numbers stay valid only if recolouring cannot change how bright the
  // field is. Tint the hue, hold the luminance, and no album and no slider
  // position can push secondary text under AA.
  // ------------------------------------------------------------------
  function rgb2hsl(r, g, b) {
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
    var h = 0, s = 0, l = (mx + mn) / 2;
    if (d) {
      s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
      if (mx === r) h = ((g - b) / d + (g < b ? 6 : 0));
      else if (mx === g) h = (b - r) / d + 2;
      else h = (r - g) / d + 4;
      h *= 60;
    }
    return [h, s, l];
  }

  function hue2rgb(p, q, t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  function hsl2rgb(h, s, l) {
    h = ((h % 360) + 360) % 360 / 360;
    if (!s) return [l, l, l];
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    var p = 2 * l - q;
    return [hue2rgb(p, q, h + 1 / 3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1 / 3)];
  }

  function shortest(a, b) {          // signed smallest angle from a to b
    return ((((b - a) % 360) + 540) % 360) - 180;
  }

  function lin(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
  }
  function relY(c) {                 // WCAG relative luminance
    return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2]);
  }

  // Solve for the HSL lightness that reproduces a target relative luminance at
  // a given hue and saturation.
  //
  // Holding HSL *lightness* constant is not enough, and the gap is not small:
  // at constant L, rotating this field's brightest colour through the hue
  // circle swings its relative luminance by 1.70x (0.12 at 240deg to 0.39 at
  // 60deg) — and still 1.46x inside the cool-lock band. HSL lightness is not
  // perceptual brightness; green at L=0.76 is far brighter than blue at
  // L=0.76. Left alone, a yellow album would have quietly undone the contrast
  // work in design.md 8d.
  //
  // Relative luminance is monotonic in L at fixed H/S, so a short bisection is
  // exact enough and costs nothing — this runs on slider moves, not per frame.
  function solveL(h, s, targetY) {
    var lo = 0, hi = 1, mid, c;
    for (var i = 0; i < 24; i++) {
      mid = (lo + hi) / 2;
      c = hsl2rgb(h, s, mid);
      if (relY(c) < targetY) lo = mid; else hi = mid;
    }
    return (lo + hi) / 2;
  }

  function hexToHS(hex) {
    var m = String(hex || "").replace("#", "");
    if (m.length !== 6 || /[^0-9a-f]/i.test(m)) return null;
    var c = rgb2hsl(parseInt(m.slice(0, 2), 16) / 255,
                    parseInt(m.slice(2, 4), 16) / 255,
                    parseInt(m.slice(4, 6), 16) / 255);
    return { h: c[0], s: c[1] };
  }

  function rgbToHex(c) {
    return "#" + [0, 1, 2].map(function (i) {
      var v = Math.round(Math.max(0, Math.min(1, c[i])) * 255).toString(16);
      return v.length < 2 ? "0" + v : v;
    }).join("");
  }

  // One field colour, recoloured by the current settings.
  function tint(rgba) {
    var hsl = rgb2hsl(rgba[0], rgba[1], rgba[2]);
    var h = hsl[0], s = hsl[1], l = hsl[2];

    var src = null;
    if (CFG.colorMode === "album" && ALBUM) src = ALBUM;
    else if (CFG.colorMode === "custom") src = hexToHS(CFG.customColor);

    if (src) {
      h = h + shortest(h, src.h) * CFG.tint;
      s = s + (src.s - s) * CFG.tint * 0.6;
    }
    if (CFG.coolLock) {
      // Compress toward the palette hue rather than clamping, so a red album
      // still reads as "warmer" without ever actually being warm.
      h = PALETTE_HUE + shortest(PALETTE_HUE, h) * 0.14;
      s = Math.min(s, 0.9);
    }
    s = Math.max(0, Math.min(1, s * CFG.sat));
    // Recolour the hue, then put the luminance back exactly where it was.
    var out = hsl2rgb(h, s, solveL(h, s, relY(rgba)));
    return [out[0], out[1], out[2], rgba[3]];
  }

  // "R, G, B" for a surface, recoloured to match the field.
  function surfRGB(key) {
    if (CFG.surface === "neutral") return "0, 0, 0";
    var c = tint(SURF[key]);
    return [0, 1, 2].map(function (i) {
      return Math.round(Math.max(0, Math.min(1, c[i])) * 255);
    }).join(", ");
  }

  function applyCss() {
    var r = document.documentElement.style;
    r.setProperty("--gelo-surf-main", surfRGB("main"));
    r.setProperty("--gelo-surf-deep", surfRGB("deep"));
    r.setProperty("--gelo-surf-raised", surfRGB("raised"));
    // Accents ride the same tint(), which preserves luminance — so however far
    // the album drags the hue, dark ink on a button keeps the contrast it was
    // measured at. Album-coloured buttons cannot become unreadable buttons.
    // The field keeps the album's colour; the CHROME does not. Once colour
    // stops coming from tokens.json, a tinted button competes with a tinted
    // surface behind it and both lose. White reads on any hue, so buttons,
    // inputs and the waveform go neutral and the colour stays where it is
    // doing work. In tokens mode nothing changes.
    var native = CFG.colorMode === "tokens";
    var acc = native ? tint(FIELD.colorLine) : [1, 1, 1, 1];
    var hot = native ? tint(FIELD.colorAccent) : [0.88, 0.92, 0.96, 1];
    r.setProperty("--gelo-accent", rgbToHex(acc));
    r.setProperty("--gelo-accent-hot", rgbToHex(hot));
    r.setProperty("--gelo-accent-rgb", [0, 1, 2].map(function (i) {
      return Math.round(Math.max(0, Math.min(1, acc[i])) * 255);
    }).join(", "));
    r.setProperty("--gelo-scrim", String(CFG.scrim));
    r.setProperty("--gelo-panel", String(CFG.panel));
    r.setProperty("--gelo-spin", CFG.spin + "s");
    r.setProperty("--gelo-ui", String(CFG.ui));
    document.documentElement.classList.toggle("gelo-turntable", !!CFG.turntable);
    document.documentElement.classList.toggle("gelo-waveform", !!CFG.waveform);
    if (canvas) canvas.style.display = CFG.enabled ? "block" : "none";
  }

  function rate() { return BASE_RATE * Math.max(CFG.rate, 0.05); }

  function applyGl() {
    if (!gl || !U) return;
    ["colorBase", "colorMid", "colorHigh", "colorEdge", "colorAccent"].forEach(function (k) {
      gl.uniform4fv(U[k], tint(FIELD[k]));
    });
    var line = tint(FIELD.colorLine).map(function (v, i) {
      return i < 3 ? Math.min(v * CFG.fieldGain, 1) : v;
    });
    gl.uniform4fv(U.colorLine, line);
    gl.uniform1f(U.rippleAmplitude, 0);
    // Inert while the ripple slots are parked (see boot), but kept correct so
    // re-enabling wavefronts does not silently reintroduce the bug below.
    //
    // `material.ripple.speed` is units per REAL second, but the shader derives
    // a wavefront's radius as `age * rippleSpeed` on the same clock it uses for
    // drift — and that clock is pre-scaled. Passing the token value straight
    // through made the wavefront expand `rate` times too slowly: at 0.16 a
    // ripple took about eleven seconds to cross the window, which measured as
    // zero frame-to-frame change and read as "ripples are broken" when they
    // were merely crawling. Divide it back out, and re-divide on every change.
    gl.uniform1f(U.rippleSpeed, RIPPLE.speed / rate());
  }

  function boot() {
    if (document.getElementById("gelo-xmb-field")) return;
    if (!document.body) return setTimeout(boot, 200);

    // Transparency lives here, not in user.css, so that deleting this file
    // removes the hole and the thing filling it in one step.
    var style = document.createElement("style");
    style.id = "gelo-xmb-field-style";
    style.textContent = [
      "html:root {",
      "  --gelo-scrim: 0.68; --gelo-panel: 0.88; --gelo-spin: 14s; --gelo-ui: 1;",
      "  --gelo-surf-main: __SCRIM_RGB__; --gelo-surf-deep: __SCRIM_RGB__;",
      "  --gelo-surf-raised: __SCRIM_RGB__;",
      "  --gelo-accent: #8cc6f7; --gelo-accent-hot: #85dbef;",
      "  --gelo-accent-rgb: 140, 198, 247;",
      "  --gelo-wave-hot: none; --gelo-wave-dim: none;",
      "}",
      // The rest of the UI — sidebar, top bar, player bar, cards — rebuilt
      // from the `--spice-rgb-*` triplets spicetify already emits, so one
      // alpha opens every opaque surface onto the field at once. The main
      // view has its own scrim and the right panel its own alpha; this is
      // everything else.
      "html:root {",
      "  --spice-sidebar: rgba(var(--gelo-surf-deep), var(--gelo-ui));",
      "  --spice-player: rgba(var(--gelo-surf-deep), var(--gelo-ui));",
      "  --spice-card: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --spice-main-elevated: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --spice-highlight: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      // Buttons, selection and notifications follow the colour source too.
      "  --spice-button: var(--gelo-accent);",
      "  --spice-button-active: var(--gelo-accent-hot);",
      "  --spice-selected-row: var(--gelo-accent);",
      "  --spice-notification: var(--gelo-accent);",
      "  --spice-rgb-button: var(--gelo-accent-rgb);",
      // The triplets themselves, and `--spice-main`, which nothing above
      // touched. Anything painting `var(--spice-main)` or rebuilding a colour
      // from `rgba(var(--spice-rgb-*), a)` kept the token navy — which is why
      // the Related-music-videos box stayed blue while the panel around it
      // went red.
      "  --spice-main: rgba(var(--gelo-surf-main), var(--gelo-ui));",
      "  --spice-rgb-main: var(--gelo-surf-main);",
      "  --spice-rgb-sidebar: var(--gelo-surf-deep);",
      "  --spice-rgb-player: var(--gelo-surf-deep);",
      "  --spice-rgb-card: var(--gelo-surf-raised);",
      "  --spice-rgb-main-elevated: var(--gelo-surf-raised);",
      "  --spice-rgb-highlight: var(--gelo-surf-raised);",
      // The home shortcuts strip — the row with All / Music / Podcasts /
      // Audiobooks and the playlist tiles under it — paints an art-derived
      // gradient through `--background-image`, on a hashed styled-components
      // class. That is what stayed indigo while everything around it followed
      // the palette, and what shifted hue when a tile was hovered.
      //
      // Neutralise the variable rather than chase the class. `!important`
      // because Spotify sets this one INLINE per hovered item, and inline
      // beats a stylesheet without it. What remains underneath is a gradient
      // to `--spice-main`, which now follows the colour source like the rest.
      "  --background-image: none !important;",
      // Half the chrome does not read `--spice-*` at all. The left panel and
      // the home interior paint Encore's `--background-base`, and the top bar
      // `--background-elevated-base`, which is why the first UI-opacity pass
      // left them stubbornly solid while everything else opened up. Alpha
      // those too and the whole shell goes translucent together.
      //
      // This also permanently kills Spotify's album-art tint, which arrived
      // through this same variable.",
      "  --background-base: rgba(var(--gelo-surf-main), var(--gelo-ui));",
      "  --background-elevated-base: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --background-elevated-highlight: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --background-tinted-base: rgba(var(--gelo-surf-main), calc(var(--gelo-ui) * 0.10));",
      "}",
      // :root is not enough. A custom property resolves to the nearest
      // ancestor that declares it, and `.encore-dark-theme` re-declares these
      // (`--background-elevated-base: #1f1f1f`) much closer to the element —
      // which is why the now-playing panel's inner boxes stayed solid while
      // the panel around them went translucent. Override at the theme class
      // so the whole subtree inherits the alpha.
      //
      // Only the neutral surface values are touched. Encore also declares
      // these inside narrower selectors for alerts and inverted controls, and
      // those are more specific, so they still win — which is correct.
      ".encore-dark-theme, .encore-light-theme {",
      "  --background-base: rgba(var(--gelo-surf-main), var(--gelo-ui));",
      "  --background-elevated-base: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --background-elevated-highlight: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "  --section-background-base: rgba(var(--gelo-surf-raised), var(--gelo-ui));",
      "}",
      // The panel's own boxes — cover art, About the artist, Credits, queue —
      // painted directly, so they follow UI opacity whatever Spotify decides
      // to resolve those variables to next release.
      ".main-nowPlayingView-section {",
      "  background-color: rgba(var(--gelo-surf-raised),",
      "    calc(var(--gelo-ui) * var(--gelo-panel) * 0.92)) !important;",
      "}",
      // This wrapper lays a near-opaque black gradient over the panel, which
      // reads as a dark slab once anything behind it is meant to show.
      ".main-nowPlayingView-mainWrapper {",
      "  background: rgba(var(--gelo-surf-main),",
      "    calc(var(--gelo-ui) * var(--gelo-panel) * 0.35)) !important;",
      "}",
      // Belt and braces on the semantic home classes, so this does not rely on
      // the hashed element keeping its shape.
      ".main-home-homeHeader,",
      ".main-home-filterChipsContainer,",
      ".main-home-filterChipsSection,",
      ".main-home-filterChipsSectionActive {",
      "  background-image: none !important;",
      "  background-color: transparent !important;",
      "}",
      ".main-nowPlayingView-coverArtContainer,",
      ".main-nowPlayingView-aboutArtist,",
      ".main-nowPlayingView-credits {",
      "  background-color: transparent !important;",
      "}",
      "body, .Root__top-container { background: transparent !important; }",
      // A scrim, not full transparency. Text sits on this surface, and the
      // field's bright end is filament cores — measured by isolating the
      // pixels that move between two frames, the top 5% put secondary text at
      // 4.17:1, under AA and a regression on the flat 5.78:1.
      ".Root__main-view, .Root__main-view .os-content {",
      "  background-color: rgba(var(--gelo-surf-main), calc(var(--gelo-ui) * var(--gelo-scrim))) !important;",
      "}",
      // A brighter secondary ink, scoped to the surface that now has a field
      // under it — the same move `hint` makes for inputs in the editor theme.
      ".Root__main-view { --spice-subtext: __SUBFIELD__; }",
      // Spotify tints the main view from the current album art, and making
      // that surface translucent is what exposed it: a maroon cover turned the
      // whole middle panel warm red, straight through the one rule the palette
      // does not bend. The tint arrives as `--background-base`, painted by the
      // action-bar gradient. Kill that layer and neutralise the tinted set.
      ".Root__main-view .main-actionBarBackground-background {",
      "  background-image: none !important;",
      "}",
      ".Root__main-view {",
      "  --background-tinted-base: rgba(var(--gelo-surf-main), 0.06);",
      "  --background-tinted-highlight: rgba(var(--gelo-surf-main), 0.10);",
      "  --background-tinted-press: rgba(var(--gelo-surf-main), 0.14);",
      "}",
      // The right panel. Its sections paint --section-background-base rather
      // than a background of their own, so the variable is the lever.
      ".Root__right-sidebar {",
      "  background-color: rgba(var(--gelo-surf-main), calc(var(--gelo-ui) * var(--gelo-panel))) !important;",
      "  --section-background-base: rgba(var(--gelo-surf-raised), calc(var(--gelo-ui) * var(--gelo-panel) * 0.92));",
      "}",
      ".Root__right-sidebar .main-nowPlayingView-section {",
      "  background-color: rgba(var(--gelo-surf-raised), calc(var(--gelo-ui) * var(--gelo-panel) * 0.92)) !important;",
      "}",
      "#gelo-xmb-field {",
      "  position: fixed; inset: 0; width: 100%; height: 100%;",
      "  z-index: -1; pointer-events: none; display: block;",
      "}",

      // ---- turntable ------------------------------------------------
      // `position: relative` is the one layout property this stylesheet sets,
      // and only because ::after needs a containing block. It does not move
      // anything.
      // The waveform IS the playback bar — the track's loudness envelope in
      // place of the flat progress strip, filling as it plays.
      //
      // Height comes from `--progress-bar-height`, which Spotify already
      // drives the bar from, so this asks for room through the app's own
      // variable rather than editing a box model. Same lesson as the Encore
      // colour sets and the turntable: set the variable, do not fight the
      // layout.
      //
      // Both layers are painted on the *background* element, which is static
      // and full width. `.x-progressBar-fillColor` cannot carry the played
      // half: it is a full-width element moved with `transform: translateX`,
      // so a background on it would slide across rather than be revealed. The
      // hot layer is instead pre-clipped to the playhead when generated —
      // CSS cannot clip a background, and scaling one would squash the
      // waveform rather than uncover it.
      // `--progress-bar-height` is declared on `.progress-bar` itself, so that
      // is what has to be overridden — setting it on an ancestor does nothing.
      "html.gelo-waveform.gelo-has-wave .progress-bar {",
      "  --progress-bar-height: 26px;",
      "  --progress-bar-radius: 3px;",
      "}",
      "html.gelo-waveform.gelo-has-wave .x-progressBar-progressBarBg {",
      "  background-color: transparent !important;",
      "  background-image: var(--gelo-wave-hot), var(--gelo-wave-dim) !important;",
      "  background-size: 100% 100%, 100% 100% !important;",
      "  background-repeat: no-repeat, no-repeat !important;",
      "  background-position: center, center !important;",
      "}",
      // The solid fill would sit on top of the waveform, so it steps aside.
      "html.gelo-waveform.gelo-has-wave .x-progressBar-fillColor {",
      "  background-color: transparent !important;",
      "  box-shadow: none !important;",
      "}",
      "@keyframes gelo-spin { to { transform: rotate(360deg); } }",
      // Styled on the IMAGE, never the container.
      //
      // The first attempt put `position/overflow/border-radius` and an ::after
      // on `.main-nowPlayingView-coverArt` and the artwork vanished entirely —
      // the slot measured as panel background with none of the cover in it.
      // Spotify sizes that container itself, so touching its box model is a
      // way to lose the contents. The image cannot affect layout, so this
      // cannot.
      //
      // Grooves are a stack of inset ring shadows rather than a pseudo-element,
      // because an <img> has none.
      "html.gelo-turntable .main-nowPlayingView-coverArt img,",
      "html.gelo-turntable .main-nowPlayingView-coverArt .main-image-image {",
      "  border-radius: 50%;",
      "  animation: gelo-spin var(--gelo-spin) linear infinite;",
      "  animation-play-state: paused;",
      "  box-shadow:",
      "    inset 0 0 0 2px rgba(0,0,0,0.30),",
      "    inset 0 0 0 14px rgba(255,255,255,0.045),",
      "    inset 0 0 0 15px rgba(0,0,0,0.22),",
      "    inset 0 0 0 30px rgba(255,255,255,0.04),",
      "    inset 0 0 0 31px rgba(0,0,0,0.20),",
      "    inset 0 0 0 48px rgba(255,255,255,0.035),",
      "    inset 0 0 0 49px rgba(0,0,0,0.18),",
      "    0 0 0 1px rgba(var(--spice-rgb-button), 0.18),",
      "    0 10px 36px rgba(var(--spice-rgb-shadow), 0.55);",
      "}",
      "html.gelo-turntable.gelo-playing .main-nowPlayingView-coverArt img,",
      "html.gelo-turntable.gelo-playing .main-nowPlayingView-coverArt .main-image-image {",
      "  animation-play-state: running;",
      "}",
    ].join("\n");
    document.head.appendChild(style);

    canvas = document.createElement("canvas");
    canvas.id = "gelo-xmb-field";
    document.body.insertBefore(canvas, document.body.firstChild);

    gl = canvas.getContext("webgl2", { antialias: false, alpha: true });
    if (!gl) { teardown(style); return; }

    function compile(type, src) {
      var s = gl.createShader(type);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
        console.error("[gelo-xmb]", gl.getShaderInfoLog(s));
        return null;
      }
      return s;
    }

    var vs = compile(gl.VERTEX_SHADER, VERT);
    var fs = compile(gl.FRAGMENT_SHADER, FRAG);
    if (!vs || !fs) { teardown(style); return; }

    var prog = gl.createProgram();
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
      console.error("[gelo-xmb]", gl.getProgramInfoLog(prog));
      teardown(style); return;
    }
    gl.useProgram(prog);

    var buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    var loc = gl.getAttribLocation(prog, "pos");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    U = {};
    ["time", "resolution", "colorBase", "colorMid", "colorHigh", "colorEdge",
     "colorLine", "colorAccent", "rippleSpeed", "rippleWidth",
     "rippleAmplitude", "rippleA", "rippleB", "rippleC", "rippleD"
    ].forEach(function (n) { U[n] = gl.getUniformLocation(prog, n); });

    gl.uniform1f(U.rippleWidth, RIPPLE.width);
    applyGl();
    applyCss();

    // The ripple slots are parked permanently out of range.
    //
    // The wavefronts read as concentric rings drawn *over* the field rather
    // than as the field moving, which is the opposite of the reference: XMB's
    // motion is in the ribbons themselves. Beats now surge the band drift
    // instead — same input, and it moves the thing that is supposed to move.
    //
    // The uniforms are set explicitly rather than left at their defaults,
    // because an unset vec4 is all zeroes, and a birth time of 0 would render
    // one real ripple during the first 2.5 units of the clock.
    ["rippleA", "rippleB", "rippleC", "rippleD"].forEach(function (n) {
      gl.uniform4fv(U[n], [0, 0, -999, 0]);
    });
    gl.uniform1f(U.rippleAmplitude, 0);

    function resize() {
      var d = Math.min(window.devicePixelRatio || 1, 1.5);
      var w = Math.max(1, Math.round(canvas.clientWidth * d));
      var h = Math.max(1, Math.round(canvas.clientHeight * d));
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w; canvas.height = h;
        gl.viewport(0, 0, w, h);
        gl.uniform2f(U.resolution, w, h);
      }
    }

    // Time is ACCUMULATED rather than derived from elapsed*rate, so moving the
    // rate slider changes the speed from now on instead of jumping the clock
    // and teleporting every live ripple.
    var tAcc = 0, tPrev = performance.now(), kick = 0;
    function clock() { return tAcc; }

    // A beat adds to the drift rate and decays back, so the ribbons lurch and
    // settle. Reactivity scales the surge; at 0 the field just drifts.
    function ripple() {
      if (!CFG.enabled) return;
      kick = Math.min(kick + 0.55 * CFG.reactivity, 3.0);
    }

    var last = 0;
    function draw(now) {
      frame = requestAnimationFrame(draw);
      var dt = Math.min((now - tPrev) / 1000, 0.1);
      tAcc += dt * (rate() + kick);
      kick *= Math.pow(0.02, dt / 0.30);      // ~0.3s to settle
      tPrev = now;
      if (now - last < 1000 / FPS_CAP) return;
      last = now;
      if (!CFG.enabled) return;
      resize();
      gl.uniform1f(U.time, clock());
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    frame = requestAnimationFrame(draw);

    // The desktop wallpaper keeps rendering behind maximised windows because
    // wlr-layer-shell exposes no occlusion signal. A web page does, so use it.
    document.addEventListener("visibilitychange", function () {
      if (document.hidden) {
        cancelAnimationFrame(frame);
      } else {
        last = 0; tPrev = performance.now();
        frame = requestAnimationFrame(draw);
      }
    });

    startBeats(ripple);
    installPanel();
  }

  function teardown(style) {
    if (style) style.remove();
    if (canvas) canvas.remove();
    canvas = null; gl = null; U = null;
  }

  // ------------------------------------------------------------------
  // Waveform.
  //
  // `segments[].loudness_max` is dB, roughly -60..0. Normalised and drawn as
  // a mirrored bar envelope. Two images: a dim one for the whole track and a
  // hot one clipped to the playhead, regenerated a few times a second rather
  // than per frame — half a second of playhead precision is invisible, and
  // toDataURL is far too expensive to run at 60Hz.
  // ------------------------------------------------------------------
  var WAVE = { segs: null, dur: 0, lastPct: -1, lastAt: 0 };
  var WAVE_W = 900, WAVE_H = 64;

  function drawWave(fraction, colour, alpha) {
    var cv = document.createElement("canvas");
    cv.width = WAVE_W; cv.height = WAVE_H;
    var ctx = cv.getContext("2d");
    if (!ctx || !WAVE.segs || !WAVE.dur) return "none";
    ctx.fillStyle = colour;
    ctx.globalAlpha = alpha;
    var bars = 220, bw = WAVE_W / bars, si = 0;
    for (var i = 0; i < bars; i++) {
      var t = (i / bars) * WAVE.dur;
      if ((i / bars) > fraction) break;
      while (si < WAVE.segs.length - 1 && WAVE.segs[si + 1].start <= t) si++;
      var db = WAVE.segs[si].loudness_max;
      if (typeof db !== "number") db = -30;
      var amp = Math.max(0, Math.min(1, (db + 46) / 46));
      amp = Math.pow(amp, 1.4);
      var hgt = Math.max(1.5, amp * WAVE_H * 0.72);
      ctx.fillRect(i * bw + bw * 0.18, (WAVE_H - hgt) / 2, bw * 0.64, hgt);
    }
    try { return 'url("' + cv.toDataURL("image/png") + '")'; }
    catch (e) { return "none"; }
  }

  function accentHex() {
    return CFG.colorMode === "tokens" ? rgbToHex(tint(FIELD.colorLine)) : "#ffffff";
  }

  function refreshWave(pct, force) {
    if (!CFG.waveform || !WAVE.segs) return;
    var now = Date.now();
    if (!force && (now - WAVE.lastAt < 450 || Math.abs(pct - WAVE.lastPct) < 0.004)) return;
    WAVE.lastAt = now; WAVE.lastPct = pct;
    document.documentElement.classList.add("gelo-has-wave");
    var r = document.documentElement.style;
    r.setProperty("--gelo-wave-hot", drawWave(pct, accentHex(), 0.85));
    if (force) r.setProperty("--gelo-wave-dim", drawWave(1, accentHex(), 0.18));
  }

  function clearWave() {
    WAVE.segs = null; WAVE.lastPct = -1;
    document.documentElement.classList.remove("gelo-has-wave");
    var r = document.documentElement.style;
    r.setProperty("--gelo-wave-hot", "none");
    r.setProperty("--gelo-wave-dim", "none");
  }

  // ------------------------------------------------------------------
  // Album colour. Best-effort in every direction: two different Spicetify
  // APIs, either of which may be absent or reject, and a null result simply
  // means the field keeps its token colours.
  // ------------------------------------------------------------------
  function readAlbumColour(uri) {
    var S = window.Spicetify;
    if (!S) return;

    function accept(hex) {
      if (!hex || typeof hex !== "string") return false;
      var m = hex.replace("#", "");
      if (m.length !== 6 || /[^0-9a-f]/i.test(m)) return false;
      var r = parseInt(m.slice(0, 2), 16) / 255,
          g = parseInt(m.slice(2, 4), 16) / 255,
          b = parseInt(m.slice(4, 6), 16) / 255;
      var hsl = rgb2hsl(r, g, b);
      if (hsl[1] < 0.08) return false;     // a grey cover carries no hue
      ALBUM = { h: hsl[0], s: hsl[1], hex: "#" + m.toLowerCase() };
      applyGl(); applyCss();
      refreshWave(WAVE.lastPct < 0 ? 0 : WAVE.lastPct, true);
      var sw = document.getElementById("gelo-album-swatch");
      if (sw) paintSwatch(sw);
      return true;
    }

    try {
      if (S.colorExtractor) {
        S.colorExtractor(uri).then(function (c) {
          if (!accept(c && (c.VIBRANT || c.PROMINENT || c.DESATURATED))) fromPixels();
        }).catch(fromPixels);
        return;
      }
      if (S.extractColorPreset) {
        S.extractColorPreset(uri).then(function (p) {
          var first = p && p[0];
          if (!accept(first && first.colorRaw && first.colorRaw.hex)) fromPixels();
        }).catch(fromPixels);
        return;
      }
    } catch (e) { /* fall through */ }
    fromPixels();
  }

  // Reading the cover art directly.
  //
  // This is the path that has to work, so it does not lean on Spotify
  // internals: Spotify's image CDN answers with `access-control-allow-origin:
  // *` (verified against image-cdn-fa.spotifycdn.com), which means an
  // anonymous <img> can be drawn to a canvas and sampled. The extractor APIs
  // above are a nicety; this is the guarantee.
  //
  // The artwork element is found rather than assumed — the first version
  // queried one selector and came back empty, and an empty read is
  // indistinguishable from "this cover has no colour" unless you look. It also
  // retries, because the DOM art swaps in a beat or two after the track does.
  function coverUrl() {
    var sels = [
      ".main-nowPlayingView-coverArt img",
      ".main-nowPlayingView-coverArt .main-image-image",
      ".main-nowPlayingWidget-coverArt img",
      "[data-testid=\"cover-art-image\"] img",
      "[data-testid=\"cover-art-image\"]",
      ".main-coverSlotCollapsed-container img"
    ];
    for (var i = 0; i < sels.length; i++) {
      var el = document.querySelector(sels[i]);
      if (!el) continue;
      var u = el.currentSrc || el.src || el.getAttribute("src");
      if (!u) {
        try {
          var m = /url\(["\']?(.*?)["\']?\)/.exec(
            getComputedStyle(el).backgroundImage || "");
          if (m) u = m[1];
        } catch (e) { /* ignore */ }
      }
      if (u && /^https?:/.test(u)) return u;
    }
    return null;
  }

  function fromPixels(attempt) {
    attempt = attempt || 0;
    if (attempt > 5) return;
    var src = coverUrl();
    if (!src) { setTimeout(function () { fromPixels(attempt + 1); }, 700); return; }

    var probe = new Image();
    probe.crossOrigin = "anonymous";
    probe.onerror = function () {
      setTimeout(function () { fromPixels(attempt + 1); }, 700);
    };
    probe.onload = function () {
      try {
        var n = 48, cv = document.createElement("canvas");
        cv.width = n; cv.height = n;
        var ctx = cv.getContext("2d");
        ctx.drawImage(probe, 0, 0, n, n);
        var d = ctx.getImageData(0, 0, n, n).data;
        // Average hue as a unit vector, weighted by saturation squared, so a
        // mostly-grey cover with one saturated element still resolves and hues
        // near 0/360 do not average to the opposite side of the circle.
        var x = 0, y = 0, sw = 0, ss = 0;
        for (var i = 0; i < d.length; i += 4) {
          if (d[i + 3] < 128) continue;
          var hsl = rgb2hsl(d[i] / 255, d[i + 1] / 255, d[i + 2] / 255);
          if (hsl[2] < 0.08 || hsl[2] > 0.96) continue;   // near-black / blown out
          var w = hsl[1] * hsl[1];
          var rad = hsl[0] * Math.PI / 180;
          x += Math.cos(rad) * w; y += Math.sin(rad) * w;
          ss += hsl[1] * w; sw += w;
        }
        if (sw <= 0) { setTimeout(function () { fromPixels(attempt + 1); }, 700); return; }
        var h = ((Math.atan2(y, x) * 180 / Math.PI) % 360 + 360) % 360;
        var sat = Math.max(0, Math.min(1, ss / sw));
        if (sat < 0.06) return;                 // genuinely a greyscale cover
        ALBUM = { h: h, s: sat, hex: rgbToHex(hsl2rgb(h, sat, 0.55)) };
        applyGl(); applyCss();
        refreshWave(WAVE.lastPct < 0 ? 0 : WAVE.lastPct, true);
        var sw2 = document.getElementById("gelo-album-swatch");
        if (sw2) paintSwatch(sw2);
      } catch (e) {
        // Tainted canvas: the CDN stopped sending CORS. Keep token colours.
      }
    };
    probe.src = src;
  }

  // ------------------------------------------------------------------
  // Beats -> ripples, and playback state -> the turntable.
  //
  // Spotify's audio analysis is best-effort: it is missing for local files
  // and most podcasts, and the call can simply fail. Every path here
  // degrades to fewer ripples, never to a broken field.
  // ------------------------------------------------------------------
  function startBeats(ripple) {
    var beats = [], idx = 0, uri = null, lastFallback = 0;

    function reload(u) {
      beats = []; idx = 0;
      var S = window.Spicetify;
      if (!S || !S.getAudioData) return;
      ripple();                             // a track change is itself an event
      readAlbumColour(u);
      clearWave();
      S.getAudioData().then(function (d) {
        beats = (d && d.beats) ? d.beats : [];
        idx = 0;
        if (d && d.segments && d.segments.length) {
          WAVE.segs = d.segments;
          WAVE.dur = (d.track && d.track.duration)
            || d.segments[d.segments.length - 1].start
               + d.segments[d.segments.length - 1].duration;
          refreshWave(0, true);
        }
      }).catch(function () { beats = []; });
    }

    // Watch the ARTWORK, not the track change.
    //
    // Extraction used to fire on track change and retry on a fixed schedule,
    // which is a race: the DOM swaps the cover a beat or two later, and if the
    // retries ran out first the read silently produced nothing. The symptom
    // was the panel disagreeing with itself — the colour swatch showing a
    // magenta taken from the *previous* cover while "Detected" correctly said
    // nothing had been read for this one.
    //
    // The artwork URL is the actual signal, so poll that. It self-heals for
    // late loads, video mode, and covers that arrive out of order.
    var lastCover = null;
    setInterval(function () {
      if (!CFG.enabled) return;
      var u = coverUrl();
      if (u && u !== lastCover) { lastCover = u; fromPixels(0); }
    }, 600);

    setInterval(function () {
      var S = window.Spicetify;
      if (!S || !S.Player || !S.Player.data) return;

      var playing = !!(S.Player.isPlaying && S.Player.isPlaying());
      document.documentElement.classList.toggle("gelo-playing", playing);

      if (!CFG.enabled) return;
      var now = S.Player.data.item && S.Player.data.item.uri;
      if (now !== uri) { uri = now; reload(now); return; }
      if (!playing) return;

      // More reactivity also means a lower bar for what counts as a beat.
      var floor = Math.max(0.05, 0.55 - 0.3 * CFG.reactivity);

      if (!beats.length) {
        if (WAVE.dur) {
          var p0 = S.Player.getProgress() / 1000;
          refreshWave(Math.max(0, Math.min(1, p0 / WAVE.dur)), false);
        }
        var t = Date.now();
        if (t - lastFallback > 2400 / Math.max(CFG.reactivity, 0.2)) {
          lastFallback = t;
          ripple();
        }
        return;
      }

      var pos = S.Player.getProgress() / 1000;
      if (WAVE.dur) refreshWave(Math.max(0, Math.min(1, pos / WAVE.dur)), false);

      // Fire AHEAD of the timestamp. The analysis timeline is where the beat
      // is in the file, not where it is in the air — Spotify's output
      // buffering puts the two apart, and the poll and frame cap add their own
      // delay on top. Anticipating by `lead` cancels the lot. The right value
      // depends on the output path, hence a slider rather than a constant.
      var p = pos + CFG.lead;
      if (idx > 0 && beats[idx - 1] && p < beats[idx - 1].start - 1) idx = 0;

      while (idx < beats.length && beats[idx].start <= p) {
        if (p - beats[idx].start < 0.25 && beats[idx].confidence > floor) {
          // Off-centre and low, so the field answers the music rather than
          // pulsing at it from the middle of the screen.
          ripple();
        }
        idx++;
      }
    }, 20);
  }

  // ------------------------------------------------------------------
  // The control panel.
  //
  // Built as plain DOM rather than through PopupModal, so it depends on as
  // little of Spicetify's API surface as possible — the whole layer has to
  // survive Spotify updates, and every API touched is a way to not.
  // ------------------------------------------------------------------
  var SLIDERS = [
    ["tint", "Tint strength", 0, 1, 0.05],
    ["fieldGain", "Field brightness", 0, 2, 0.05],
    ["sat", "Field saturation", 0, 2, 0.05],
    ["scrim", "Main view scrim", 0.2, 0.95, 0.01],
    ["ui", "UI opacity", 0.3, 1, 0.01],
    ["panel", "Right panel", 0.3, 1, 0.01],
    ["reactivity", "Beat reactivity", 0, 2, 0.05],
    ["lead", "Beat lead", 0, 0.4, 0.01],
    ["rate", "Drift rate", 0, 2, 0.05],
    ["spin", "Spin period (s)", 3, 40, 1]
  ];
  var TOGGLES = [
    ["enabled", "Field"],
    ["coolLock", "Cool lock"],
    ["turntable", "Turntable"],
    ["waveform", "Waveform bar"]
  ];

  function paintSwatch(el) {
    var src = CFG.colorMode === "album" ? (ALBUM && ALBUM.hex)
            : CFG.colorMode === "custom" ? CFG.customColor
            : null;
    el.style.background = src || "transparent";
    el.style.borderStyle = src ? "solid" : "dashed";
    el.title = src || "using tokens.json";
    var lbl = document.getElementById("gelo-album-label");
    if (lbl) {
      lbl.textContent = CFG.colorMode === "album"
        ? (ALBUM && ALBUM.hex ? ALBUM.hex : "reading cover…")
        : CFG.colorMode === "custom" ? CFG.customColor : "tokens.json";
    }
  }

  function installPanel() {
    // `Spicetify.Menu` is not populated yet when this file first runs, so a
    // single attempt registers nothing and — because the failure is caught —
    // does it silently. The item was simply absent from the profile menu while
    // every other spicetify entry showed up. Retry until it takes.
    var tries = 0;
    (function register() {
      if (++tries > 100) return;                 // ~30s, then give up quietly
      try {
        if (window.Spicetify && Spicetify.Menu && Spicetify.Menu.Item) {
          new Spicetify.Menu.Item("XMB field", false, function (self) {
            toggle(); if (self && self.setState) self.setState(false);
          }).register();
          return;
        }
      } catch (e) { /* not ready yet */ }
      setTimeout(register, 300);
    })();

    document.addEventListener("keydown", function (ev) {
      if (ev.ctrlKey && ev.altKey && (ev.key === "X" || ev.key === "x")) {
        ev.preventDefault(); toggle();
      }
    });
  }

  function toggle() {
    var open = document.getElementById("gelo-xmb-panel");
    if (open) { open.remove(); return; }
    document.body.appendChild(buildPanel());
  }

  function buildPanel() {
    var wrap = document.createElement("div");
    wrap.id = "gelo-xmb-panel";
    wrap.style.cssText = [
      "position:fixed", "right:24px", "bottom:112px", "z-index:9999",
      "width:300px", "max-height:74vh", "overflow-y:auto", "padding:16px",
      "border-radius:__RADIUS__px",
      // Opaque on purpose. The panel reads `--gelo-surf-*` so it follows the
      // palette, but NOT `--gelo-ui` — a settings panel you cannot read at low
      // UI opacity is a settings panel you cannot use to raise UI opacity.
      "background:linear-gradient(180deg," +
        "rgba(var(--gelo-surf-raised),0.97) 0%," +
        "rgba(var(--gelo-surf-deep),0.97) 100%)",
      "border:1px solid rgba(var(--spice-rgb-button),0.20)",
      "box-shadow:0 6px 32px rgba(var(--spice-rgb-shadow),0.5)," +
        "0 0 __GLOWEXT__px rgba(var(--spice-rgb-button),0.15)",
      "color:var(--spice-text)",
      "font-size:12px", "letter-spacing:0.02em"
    ].join(";");

    var head = document.createElement("div");
    head.style.cssText = "display:flex;justify-content:space-between;align-items:center;margin-bottom:12px";
    var title = document.createElement("div");
    title.textContent = "XMB field";
    title.style.cssText = "font-size:13px";
    var close = document.createElement("button");
    close.textContent = "×";
    close.style.cssText = "background:none;border:0;color:var(--spice-subtext);cursor:pointer;font-size:16px;line-height:1";
    close.onclick = function () { wrap.remove(); };
    head.appendChild(title); head.appendChild(close);
    wrap.appendChild(head);

    // ---- colour source -------------------------------------------------
    var srcRow = row("Colour source");
    var sel = document.createElement("select");
    sel.style.cssText = "background:var(--spice-player);color:var(--spice-text);"
      + "border:1px solid rgba(var(--spice-rgb-button),0.25);border-radius:4px;"
      + "padding:2px 6px;font-size:12px;cursor:pointer";
    [["tokens", "tokens.json"], ["custom", "Custom"], ["album", "Album art"]]
      .forEach(function (o) {
        var op = document.createElement("option");
        op.value = o[0]; op.textContent = o[1];
        if (CFG.colorMode === o[0]) op.selected = true;
        sel.appendChild(op);
      });
    srcRow.appendChild(sel);
    wrap.appendChild(srcRow);

    var pickRow = row("Colour");
    var swatch = document.createElement("span");
    swatch.id = "gelo-album-swatch";
    swatch.style.cssText = "width:18px;height:18px;border-radius:4px;display:inline-block;"
      + "border:1px solid rgba(var(--spice-rgb-button),0.35);margin-left:auto";
    var label = document.createElement("span");
    label.id = "gelo-album-label";
    label.style.cssText = "color:var(--spice-subtext);font-variant-numeric:tabular-nums;"
      + "margin:0 8px 0 8px";
    var picker = document.createElement("input");
    picker.type = "color"; picker.value = CFG.customColor;
    picker.style.cssText = "width:24px;height:20px;padding:0;border:0;background:none;cursor:pointer";
    var hex = document.createElement("input");
    hex.type = "text"; hex.value = CFG.customColor; hex.spellcheck = false;
    hex.style.cssText = "width:74px;background:var(--spice-player);color:var(--spice-text);"
      + "border:1px solid rgba(var(--spice-rgb-button),0.25);border-radius:4px;"
      + "padding:2px 6px;font-size:12px;margin-left:8px";

    function setCustom(v, from) {
      if (!hexToHS(v)) return;
      CFG.customColor = v.toLowerCase();
      if (from !== "picker") picker.value = CFG.customColor;
      if (from !== "hex") hex.value = CFG.customColor;
      paintSwatch(swatch); applyGl(); applyCss();
      refreshWave(WAVE.lastPct, true); save();
    }
    picker.oninput = function () { setCustom(picker.value, "picker"); };
    hex.onchange = function () { setCustom(hex.value.trim(), "hex"); };

    function syncMode() {
      var custom = CFG.colorMode === "custom";
      picker.style.display = custom ? "" : "none";
      hex.style.display = custom ? "" : "none";
      label.style.display = custom ? "none" : "";
      paintSwatch(swatch);
    }
    sel.onchange = function () {
      CFG.colorMode = sel.value;
      syncMode(); applyGl(); applyCss(); refreshWave(WAVE.lastPct, true); save();
    };

    pickRow.appendChild(label);
    pickRow.appendChild(picker);
    pickRow.appendChild(hex);
    pickRow.appendChild(swatch);
    wrap.appendChild(pickRow);

    // Always show what was read off the current cover, whatever mode is
    // selected. It is the honest answer to "is it actually reading the album
    // art" — a hex here means yes, "—" means the extractors and the pixel
    // fallback both came back empty and the field is on token colours.
    var detRow = row("Detected");
    var detSw = document.createElement("span");
    detSw.style.cssText = "width:18px;height:18px;border-radius:4px;display:inline-block;"
      + "border:1px solid rgba(var(--spice-rgb-button),0.35);margin-left:8px";
    var detTxt = document.createElement("span");
    detTxt.style.cssText = "color:var(--spice-subtext);font-variant-numeric:tabular-nums;margin-left:auto";
    detRow.appendChild(detTxt); detRow.appendChild(detSw);
    wrap.appendChild(detRow);
    // Deferred, not immediate. buildPanel() runs BEFORE the node is appended,
    // so an immediate first tick fails its own `contains(wrap)` guard and never
    // reschedules — the readout then sits empty forever while the swatch beside
    // it updates fine, which reads exactly like broken colour extraction and is
    // not.
    setTimeout(function poll() {
      if (!document.body.contains(wrap)) return;
      detTxt.textContent = ALBUM && ALBUM.hex ? ALBUM.hex : "—";
      detSw.style.background = ALBUM && ALBUM.hex ? ALBUM.hex : "transparent";
      setTimeout(poll, 500);
    }, 0);

    syncMode();

    var surfRow = row("Surface style");
    var surfSel = document.createElement("select");
    surfSel.style.cssText = sel.style.cssText;
    [["tinted", "Tinted"], ["neutral", "Neutral black"]].forEach(function (o) {
      var op = document.createElement("option");
      op.value = o[0]; op.textContent = o[1];
      if (CFG.surface === o[0]) op.selected = true;
      surfSel.appendChild(op);
    });
    surfSel.onchange = function () {
      CFG.surface = surfSel.value; applyCss(); save();
    };
    surfRow.appendChild(surfSel);
    wrap.appendChild(surfRow);

    TOGGLES.forEach(function (t) {
      var r = row(t[1]);
      var chk = document.createElement("input");
      chk.type = "checkbox"; chk.checked = !!CFG[t[0]];
      chk.style.cssText = "accent-color:var(--spice-button);cursor:pointer";
      chk.onchange = function () {
        CFG[t[0]] = chk.checked; applyCss(); applyGl(); save();
      };
      r.appendChild(chk);
      wrap.appendChild(r);
    });

    SLIDERS.forEach(function (s) {
      var key = s[0], min = s[2], max = s[3], step = s[4];
      var r = row(s[1]);
      var val = document.createElement("span");
      val.textContent = fmt(key, CFG[key]);
      val.style.cssText = "color:var(--spice-subtext);font-variant-numeric:tabular-nums";
      r.appendChild(val);
      wrap.appendChild(r);

      var input = document.createElement("input");
      input.type = "range";
      input.min = min; input.max = max; input.step = step; input.value = CFG[key];
      input.style.cssText = "width:100%;margin:0 0 10px;accent-color:var(--spice-button);cursor:pointer";
      input.oninput = function () {
        CFG[key] = parseFloat(input.value);
        val.textContent = fmt(key, CFG[key]);
        applyCss(); applyGl();
      };
      input.onchange = save;
      wrap.appendChild(input);
    });

    var foot = document.createElement("div");
    foot.style.cssText = "display:flex;gap:8px;margin-top:4px";
    foot.appendChild(button("Reset", function () {
      for (var k in DEFAULTS) CFG[k] = DEFAULTS[k];
      applyCss(); applyGl(); save();
      wrap.remove(); document.body.appendChild(buildPanel());
    }));
    // The panel is a place to FIND a value, not to keep it. tokens.json is
    // still the source of truth, so make moving a setting back there one click.
    foot.appendChild(button("Copy", function (b) {
      var out = {};
      for (var k in DEFAULTS) out[k] = CFG[k];
      var text = JSON.stringify(out, null, 2);
      try {
        navigator.clipboard.writeText(text);
        b.textContent = "Copied";
        setTimeout(function () { b.textContent = "Copy"; }, 1200);
      } catch (e) { console.log("[gelo-xmb]", text); }
    }));
    wrap.appendChild(foot);

    var note = document.createElement("div");
    note.textContent = "Colour source defaults to tokens.json. Cool lock keeps "
      + "custom and album hues inside the palette. Copy a value you like back "
      + "into the token source.";
    note.style.cssText = "margin-top:10px;color:var(--spice-subtext);font-size:11px;line-height:1.4";
    wrap.appendChild(note);

    return wrap;
  }

  function fmt(key, v) {
    if (key === "hue") return Math.round(v) + "°";
    if (key === "spin") return Math.round(v) + "s";
    if (key === "lead") return Math.round(v * 1000) + "ms";
    return Number(v).toFixed(2);
  }

  function row(label) {
    var r = document.createElement("div");
    r.style.cssText = "display:flex;justify-content:space-between;align-items:center;margin-bottom:6px";
    var l = document.createElement("span");
    l.textContent = label;
    r.appendChild(l);
    return r;
  }

  function button(text, fn) {
    var b = document.createElement("button");
    b.textContent = text;
    b.style.cssText = [
      "flex:1", "padding:6px 10px", "cursor:pointer",
      "border-radius:__RADIUS__px",
      "border:1px solid rgba(var(--spice-rgb-button),0.25)",
      "background:transparent", "color:var(--spice-text)",
      "font-size:12px",
      "transition:box-shadow __DUR__ms __EASE__, border-color __DUR__ms __EASE__"
    ].join(";");
    b.onmouseenter = function () {
      b.style.boxShadow = "0 0 __GLOWEXT__px rgba(var(--spice-rgb-button),0.28)";
      b.style.borderColor = "rgba(var(--spice-rgb-button),0.5)";
    };
    b.onmouseleave = function () {
      b.style.boxShadow = "none";
      b.style.borderColor = "rgba(var(--spice-rgb-button),0.25)";
    };
    b.onclick = function () { fn(b); };
    return b;
  }

  var VERT = [
    "#version 300 es",
    "in vec2 pos;",
    "out vec2 qt_TexCoord0;",
    "void main() {",
    "  qt_TexCoord0 = pos * 0.5 + 0.5;",
    "  gl_Position = vec4(pos, 0.0, 1.0);",
    "}"
  ].join("\n");

  var FRAG = __FRAG__;

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
"""


# --------------------------------------------------------------------------
# The design system, as a page
# --------------------------------------------------------------------------

def _site_page(t: dict, slug: str, title: str, lede: str, body: str) -> str:
    """One page of the site, in the shared layout.

    Every page is styled by the tokens it documents — the card is
    `material.chrome`, the transitions are `motion.ease`. A page about a design
    system that does not use it is a screenshot with extra steps.
    """
    color, motion, radius, space = t["color"], t["motion"], t["radius"], t["space"]
    typo, mat = t["type"], t["material"]
    e = motion["ease"]

    nav_items = [
        ("index", "the system"),
        ("xmb", "the wave field"),
        ("accessibility", "accessibility"),
        ("bridge", "the bridge"),
    ]
    nav = "".join(
        f'<a href="{"index" if n == "index" else n}.html"'
        f'{" class=\"on\"" if n == slug else ""}>{label}</a>'
        for n, label in nav_items)

    css = _SITE_CSS
    for k, v in {
        "__BG0__": color["bg-0"], "__BG1__": color["bg-1"],
        "__BG2__": color["bg-2"], "__BORDER__": color["border"],
        "__TEXT1__": color["text-1"], "__TEXT2__": color["text-2"],
        "__ACCENT__": color["accent"], "__SHADE__": color["shade"],
        "__TERM_BG__": t["terminal"]["background"],
        "__TERM_FG__": t["terminal"]["foreground"],
        "__FAMILY__": ", ".join(f'"{f}"' for f in typo["families"]),
        "__EASE__": f"cubic-bezier({e[0]}, {e[1]}, {e[2]}, {e[3]})",
        "__DUR_BASE__": str(motion["duration"]["base"]),
        "__TRACK__": str(typo["trackingEm"]),
        "__RADIUS_SM__": str(radius["sm"]),
        "__SPACE_LG__": str(space["lg"]),
        "__CHROME_DARKEN__": str(round(mat["chrome"]["gradientDarken"] * 100)),
        "__SHADOW_R__": str(mat["chrome"]["shadowRadius"]),
    }.items():
        css = css.replace(k, v)

    return (
        "<!DOCTYPE html>\n<meta charset=\"utf-8\">\n"
        f"<title>{title} — gelo</title>\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        f"<!-- {BANNER} -->\n<style>{css}</style>\n"
        f"<nav>{nav}</nav>\n<main>\n"
        f"<h1>{title}</h1>\n<p class=\"lede\">{lede}</p>\n{body}\n"
        "<footer>Generated from <code>design/tokens.json</code> by "
        "<code>design/build-tokens.py</code>. Editing these pages by hand is "
        "one regenerate away from being erased.</footer>\n</main>\n")


def render_site(t: dict) -> dict:
    """The whole site. Four pages, one source, published from `docs/`."""
    color, space, radius = t["color"], t["space"], t["radius"]
    typo, motion, mat = t["type"], t["motion"], t["material"]
    term = t["terminal"]
    e = motion["ease"]

    def swatch(name: str, value: str) -> str:
        return (f'<figure class="sw"><div class="chip" style="background:{value}"></div>'
                f'<figcaption><code>{name}</code><span>{value}</span></figcaption></figure>')

    def group(keys) -> str:
        return "".join(swatch(k, color[k]) for k in keys if k in color)

    ansi = "".join(f'<div class="ansi" style="background:{c}" title="ansi[{i}] {c}"></div>'
                   for i, c in enumerate(term["ansi"]))

    rows = []
    for label, fg, bg, need in audit_pairs(t):
        ratio = contrast(fg, bg)
        if ratio < need:
            grade = "fail"
        elif ratio >= 7:
            grade = "AAA"
        elif ratio >= 4.5:
            grade = "AA"
        else:
            grade = "ok"
        rows.append(
            f'<tr class="{"pass" if ratio >= need else "fail"}"><td>{label}</td>'
            f'<td><span class="dot" style="background:{fg}"></span>'
            f'<span class="dot" style="background:{bg}"></span></td>'
            f'<td class="num">{ratio:.2f}</td><td class="num">{need:.1f}</td>'
            f'<td>{grade}</td></tr>')
    audit_table = (
        '<div class="card"><table><thead><tr><th>pair</th><th>fg / bg</th>'
        '<th class="num">ratio</th><th class="num">min</th><th>grade</th></tr>'
        f'</thead><tbody>{"".join(rows)}</tbody></table></div>')

    sizes = "".join(f'<p class="spec" style="font-size:{v}px">{k} · {v}px — '
                    f'The quick brown fox</p>' for k, v in typo["size"].items())
    weights = "".join(f'<p class="spec" style="font-weight:{v}">{k} · {v} — '
                      f'Weight never exceeds 400</p>' for k, v in typo["weight"].items())
    spaces = "".join(f'<div class="bar"><span style="width:{v}px"></span>'
                     f'<code>{k}</code><em>{v}px</em></div>'
                     for k, v in space.items())
    radii = "".join(f'<figure class="sw"><div class="chip r" style="border-radius:'
                    f'{min(v, 48)}px"></div><figcaption><code>{k}</code>'
                    f'<span>{v}px</span></figcaption></figure>'
                    for k, v in radius.items())
    durations = "".join(f'<div class="mo"><span class="ball" '
                        f'style="animation-duration:{v}ms"></span><code>{k}</code>'
                        f'<em>{v}ms</em></div>' for k, v in motion["duration"].items())
    ntok = len(collect_colour_tokens(t))

    index_body = f"""
<div class="cards">
  <a class="case" href="xmb.html"><h3>the wave field</h3>
    <p>Three approaches missed the reference. The one that worked is a bright
    core wrapped in a wide halo — and the first version rendered
    <strong>zero changed pixels over 30 seconds</strong>.</p></a>
  <a class="case" href="accessibility.html"><h3>accessibility</h3>
    <p>An audit wired into the build found a token that had failed AA on every
    light surface <strong>since the palette was inverted</strong>.</p></a>
  <a class="case" href="bridge.html"><h3>the bridge</h3>
    <p>The same tokens drive the desktop, Figma Variables and a typed
    TypeScript module. A wrong name becomes a type error.</p></a>
</div>

<h2>surfaces</h2><div class="grid">{group(("bg-0", "bg-1", "bg-2", "border"))}</div>
<h2>ink</h2><div class="grid">{group(("text-1", "text-2", "shade"))}</div>
<h2>accent — three places, system-wide</h2>
<p class="lede">Active workspace indicator, focused window border, cursor.
Nowhere else. Selection, hover and urgency are carried by elevation, ink and
opacity instead.</p>
<div class="grid">{group(("accent", "accent-dim", "accent-ink", "glow"))}</div>
<h2>wave field</h2>
<div class="grid">{group([k for k in color if k.startswith("field-")])}</div>
<h2>terminal — ansi</h2>
<p class="lede">Surfaces you work <em>in</em> are dark; chrome you work
<em>with</em> is light. The editor and Spotify derive from this block.</p>
<div class="ansi-row">{ansi}</div>
<h2>type</h2>
<div class="card">{sizes}<hr>{weights}</div>
<h2>space — 4px grid</h2><div class="card">{spaces}</div>
<h2>radius</h2><div class="grid">{radii}</div>
<h2>motion — one curve</h2>
<p class="lede"><code>cubic-bezier({e[0]}, {e[1]}, {e[2]}, {e[3]})</code>,
shared by the shell, the compositor's window animations and the lock screen.</p>
<div class="card">{durations}</div>
"""

    xmb_body = """
<h2>three approaches, two failures</h2>
<p>The reference is the PS3 XMB: many thin threads of light crossing a broad
diffuse haze. Two standard recipes missed it in different ways.</p>
<div class="card">
<p><strong>Domain-warped fBm.</strong> The usual "pretty background". Reads as
smoke. Nothing like the reference.</p>
<p><strong>A few wide gaussian bands.</strong> Better structure, right tonal
range — still wrong. A wide gaussian produces <em>fog</em>: a smear that is
brighter in the middle, not a thread that glows.</p>
<p><strong>Many thin filaments.</strong> What actually matches, and the trick
is that one gaussian cannot do it. A filament is a <em>tight bright core plus a
much wider, much fainter halo</em>:</p>
</div>
<pre class="code">float bright = exp(-d2 / (core * core));   // thin bright thread
float bloom  = exp(-d2 / (halo * halo));   // wide faint glow
return bright + bloom * 0.22;</pre>
<p>Each strand is two sines at a non-integer frequency ratio, so it reads as
cloth rather than as a test pattern, and thickness tapers down the frame to give
the field a near and a far edge.</p>

<h2>the failure that only measurement caught</h2>
<p>The first version looked correct in a screenshot and was <strong>a still
image in motion</strong>. At the specified drift rate, over a palette spanning
only 13–42 in 8-bit, the movement quantised away entirely:</p>
<div class="card"><p class="big">zero changed pixels over 30 seconds</p></div>
<p>It would have photographed as a working shader and been a lie. The habit
that caught it — screenshot, difference two frames, count — became the standard
for everything visual in this system afterwards. Short-interval differencing
tests propagation; long-interval tests drift. They catch different lies.</p>

<h2>one shader, two runtimes</h2>
<p>The same <code>xmb.frag</code> runs on the desktop wallpaper through Qt and
behind Spotify through WebGL2. The generator retargets it by rewriting
<em>only the header</em> — version pragma, uniform block, layout qualifiers —
so there is exactly one authored copy and the two cannot drift.</p>
<p>The couplings differ on purpose. On the desktop the field answers
<em>interaction</em>: a workspace switch fires a ripple from a point. Behind
Spotify it answers <em>music</em>, which has no point of origin, so beats surge
the drift of the bands instead. A ring expanding across the field reads as
something drawn over it rather than as the field moving.</p>
"""

    accessibility_body = f"""
<h2>the build asserts it</h2>
<p><code>design/build-tokens.py --audit</code> prints every foreground /
background pair the system actually puts together, with its WCAG ratio and the
threshold that applies, and exits non-zero if any fall short. The list is
<strong>curated, not generated</strong> — an all-against-all would be hundreds
of rows nobody reads, flagging combinations that never occur.</p>
<p>It audits <em>derived</em> steps too, not only the raw tokens: the editor's
dim ramp and Spotify's subtext step are computed inside the theme renderers and
are as load-bearing as anything in the token source.</p>

<h2>what it found immediately</h2>
<p>Secondary ink had failed AA on <strong>all three light surfaces</strong>
since the palette was inverted — 3.62 / 3.94 / 3.34 against a 4.5 requirement —
and it is the ink for every subtitle in the shell. The inversion pass measured
the wallpaper shader carefully and the chrome by eye. That is the gap this
closes.</p>
<p>The fix kept hue and saturation and dropped lightness 0.531 → 0.446, giving
4.88 / 5.31 / 4.51, with the luminance gap to primary ink preserved so the
two-tier hierarchy still reads.</p>

<h2>every pair, live</h2>
<p class="lede">Rendered by the same function that gates the build, so this
table cannot advertise a ratio the build does not enforce.</p>
{audit_table}

<h2>colour that cannot break contrast</h2>
<p>Spotify's field can take its hue from the album art. Recolouring naively
would undo all of the above the first time a yellow cover played: holding HSL
<em>lightness</em> constant lets relative luminance swing <strong>1.70×</strong>
across the hue circle, because HSL lightness is not perceptual brightness.</p>
<p>So the tint rotates hue and saturation, then <em>solves</em> for the
lightness that reproduces the original WCAG luminance. Measured across every
hue at four saturations, the error is <strong>0.000%</strong>. Contrast holds by
construction rather than by luck.</p>
"""

    bridge_body = f"""
<h2>one source, twelve targets</h2>
<p>{ntok} colours in <code>design/tokens.json</code> generate a Quickshell
desktop, an SDDM login theme, a terminal theme, a VS Code extension, a Spotify
theme, GTK 3 and 4, a cursor, hyprlang variables, a CSS module, this site —
and the two below. <code>--check</code> fails the build if any of them falls
behind.</p>

<h2>Figma, without a copy</h2>
<p><code>design/tokens.dtcg.json</code> is W3C Design Tokens format: what Tokens
Studio imports to create Figma Variables. Derived rather than hand-maintained,
because a second file describing the same colours is exactly the duplication
the generator exists to prevent.</p>
<p>It carries <code>$description</code> where there is a reason — that the
accent has exactly three homes, that shadows cannot come from the lightest
surface on a light palette. <strong>That is the part that does not survive a
copy-paste</strong>, and the part that stops someone spending the accent on a
fourth thing six months later.</p>

<h2>typed, so mistakes are loud</h2>
<p><code>design/tokens.ts</code> exports the palette <code>as const</code> with
key unions. Importing tokens rather than retyping a hex means a mistake is a
type error instead of a slightly-wrong blue nobody notices for a month:</p>
<pre class="code">const typo: ColorToken = "acccent";
  → TS2820: Type '"acccent"' is not assignable to type
     '"accent" | "accent-dim" | …'. Did you mean '"accent"'?</pre>
<p>Verified under <code>tsc --strict</code>, not asserted.</p>
"""

    pages = {
        "index": ("the system",
                  f"One file generates a Hyprland desktop, its terminal, editor, "
                  f"login screen, Spotify and a Figma export — {ntok} colours, "
                  f"twelve targets, one source. This page is one of them, styled "
                  f"by the tokens it documents.", index_body),
        "xmb": ("the wave field",
                "A GLSL field of filaments, running on the wallpaper and behind "
                "Spotify from one authored shader — and the version that taught "
                "this project to measure instead of look.", xmb_body),
        "accessibility": ("accessibility",
                          "Contrast is asserted by the build, not by intention. "
                          "The audit found a defect that had been shipping for "
                          "months.", accessibility_body),
        "bridge": ("the bridge",
                   "The desktop, a Figma file and a web project as the same "
                   "palette object rather than three copies that drift.",
                   bridge_body),
    }

    out = {}
    for slug, (title, lede, body) in pages.items():
        out[ROOT / "docs" / f"{slug}.html"] = _site_page(t, slug, title, lede, body)
    # Jekyll would try to process these; it must not.
    out[ROOT / "docs" / ".nojekyll"] = ""
    return out


def collect_colour_tokens(node, path: str = "") -> list:
    """Every hex value in the source, for the count on the page."""
    out = []
    if isinstance(node, dict):
        for k, v in node.items():
            if not k.startswith("$"):
                out += collect_colour_tokens(v, f"{path}.{k}" if path else k)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            out += collect_colour_tokens(v, f"{path}[{i}]")
    elif isinstance(node, str) and re.fullmatch(r"#[0-9a-fA-F]{6,8}", node):
        out.append(path)
    return out


# --------------------------------------------------------------------------
# Contrast audit
# --------------------------------------------------------------------------

def _relative_luminance(hex_: str) -> float:
    h = hex_.lstrip("#")[:6]
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * out[0] + 0.7152 * out[1] + 0.0722 * out[2]


def contrast(fg: str, bg: str) -> float:
    """WCAG 2.x contrast ratio. Alpha is ignored — every pair below is opaque
    on opaque, and a token carrying alpha is composited before it is read."""
    a, b = _relative_luminance(fg), _relative_luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def audit_pairs(t: dict) -> list:
    """Every foreground/background pair the system actually puts together.

    Written out by hand on purpose. A generic all-against-all would produce
    hundreds of rows nobody reads and would flag combinations that never occur
    — `field-base` against `text-1` is meaningless, the wave field has no text
    on it. The value is in the list being *curated*: each row is a claim that
    this pairing happens, and the threshold is the one that applies to it.

    Returns (label, fg, bg, required) tuples. 4.5 is AA for body text, 3.0 is
    AA for large text and for UI component boundaries.
    """
    c = t["color"]
    term = t["terminal"]
    ansi = term["ansi"]

    # Derived steps the generated themes use. These are computed in
    # render_vscode / render_spicetify and are as load-bearing as the raw
    # tokens, so they are audited with them rather than trusted.
    bg = term["background"]
    fg = term["foreground"]
    editor_muted = _mix(ansi[8], fg, 0.35)
    editor_dim = _mix(ansi[8], fg, 0.22)
    editor_hint = _mix(ansi[8], fg, 0.45)
    editor_raised = _mix(bg, "#ffffff", 0.06)
    editor_deep = _mix(bg, "#000000", 0.35)
    spice_sub = _mix(ansi[8], fg, 0.45)
    spice_card = _mix(bg, "#ffffff", 0.06)
    field_sub = _mix(ansi[8], fg, 0.60)

    pairs = [
        # --- desktop chrome ---
        ("primary ink on base surface", c["text-1"], c["bg-0"], 4.5),
        ("primary ink on raised chrome", c["text-1"], c["bg-1"], 4.5),
        ("primary ink on hover surface", c["text-1"], c["bg-2"], 4.5),
        ("secondary ink on base surface", c["text-2"], c["bg-0"], 4.5),
        ("secondary ink on raised chrome", c["text-2"], c["bg-1"], 4.5),
        ("secondary ink on hover surface", c["text-2"], c["bg-2"], 4.5),
        ("hairline against base surface", c["border"], c["bg-0"], 1.3),
        ("accent ink on accent", c["accent-ink"], c["accent"], 4.5),
        ("accent ink on accent-dim", c["accent-ink"], c["accent-dim"], 4.5),
        ("accent against base surface", c["accent"], c["bg-0"], 3.0),

        # --- terminal ---
        ("terminal text", fg, bg, 4.5),
        ("terminal cursor on background", term["cursor"], bg, 3.0),
    ]

    # ANSI 0 and 8 are the dim slots and are not body text; the rest are.
    for i, colour in enumerate(ansi):
        if i in (0, 8):
            continue
        pairs.append((f"terminal ansi[{i}]", colour, bg, 4.5))

    pairs += [
        # --- editor (design.md 8c) ---
        ("editor comment", editor_muted, bg, 4.5),
        ("editor line number", editor_dim, bg, 3.0),
        ("editor placeholder on input", editor_hint, editor_raised, 4.5),
        ("editor inactive tab on deep", editor_muted, editor_deep, 4.5),
        ("editor button ink on accent", bg, ansi[12], 4.5),

        # --- Spotify (design.md 8d) ---
        ("spotify text on main", fg, bg, 4.5),
        ("spotify subtext on card", spice_sub, spice_card, 4.5),
        ("spotify subtext on main", spice_sub, bg, 4.5),
        ("spotify field subtext on main", field_sub, bg, 4.5),
    ]

    # --- GTK / libadwaita dark ramp ---
    #
    # These are a whole second palette and they went in unmeasured the first
    # time, which is exactly how `text-2` shipped below AA on the light side.
    # Every surface a GTK app puts text on is listed.
    d = t["dark"]
    for surface in ("bg-0", "bg-1", "bg-2"):
        pairs.append((f"gtk ink on {surface}", d["text-1"], d[surface], 4.5))
        pairs.append((f"gtk dim ink on {surface}", d["text-2"], d[surface], 4.5))
    pairs += [
        ("gtk accent as link text", d["accent"], d["bg-1"], 4.5),
        ("gtk ink on accent fill", d["accent-ink"], d["accent"], 4.5),
        ("gtk border against window", d["border"], d["bg-0"], 1.3),
    ]
    return pairs


def run_audit(t: dict) -> int:
    """Print the contrast table; return the number of failures."""
    rows = audit_pairs(t)
    width = max(len(r[0]) for r in rows)
    failures = 0

    print("Contrast audit — WCAG 2.x, opaque pairs the system actually uses\n")
    print(f"  {'pair'.ljust(width)}  {'ratio':>6}  {'min':>5}  result")
    print(f"  {'-' * width}  {'-' * 6}  {'-' * 5}  ------")

    for label, fg, bg, need in rows:
        ratio = contrast(fg, bg)
        ok = ratio >= need
        if not ok:
            failures += 1
        grade = "AAA" if ratio >= 7 else ("AA" if ratio >= 4.5 else "--")
        mark = grade if ok else "FAIL"
        print(f"  {label.ljust(width)}  {ratio:6.2f}  {need:5.1f}  {mark}")

    print()
    if failures:
        print(f"  {failures} pair(s) below their threshold.")
    else:
        print(f"  All {len(rows)} pairs clear their thresholds.")
    return failures


# --------------------------------------------------------------------------
# Design Tokens Community Group (W3C) — the bridge out of this repo
# --------------------------------------------------------------------------

def render_dtcg(t: dict) -> str:
    """The token source in W3C DTCG format.

    Everything else this script emits is consumed by *this machine*. This one
    is the way out: DTCG is what Tokens Studio imports to create Figma
    Variables, and what most token pipelines read. The point is that the
    desktop, the Figma file and a web project can be the same palette rather
    than three drifting copies of it.

    Deliberately not hand-maintained alongside `tokens.json`: a second file
    describing the same colours is exactly the duplication this generator
    exists to prevent, so it is derived like everything else.

    `$description` carries the *reason* where there is one — that is the part
    that does not survive a copy-paste into Figma, and the part that stops
    someone using `accent` for a fourth thing.
    """
    color, space, radius = t["color"], t["space"], t["radius"]
    typo, motion, term = t["type"], t["motion"], t["terminal"]

    def group(desc: str, items: dict) -> dict:
        out = {"$description": desc}
        out.update(items)
        return out

    why = {
        "accent": "The one accent. Appears in exactly three places system-wide: "
                  "active workspace, focused window border, cursor. A fourth is a redesign.",
        "accent-ink": "What sits ON the accent. Not named `on-accent`: that camel-cases "
                      "to `onAccent`, which QML parses as a signal handler.",
        "shade": "Shadows and scrims are built from this, never from bg-0 — on a light "
                 "palette bg-0 is the lightest surface, so shadows made from it vanish.",
        "glow": "The accent at low alpha. Selection blooms rather than filling.",
    }

    colors = {}
    for k, v in color.items():
        entry = {"$type": "color", "$value": v}
        if k in why:
            entry["$description"] = why[k]
        colors[k] = entry

    spacing = {k: {"$type": "dimension", "$value": f"{v}px"} for k, v in space.items()}
    radii = {k: {"$type": "dimension", "$value": f"{v}px"} for k, v in radius.items()}

    sizes = {k: {"$type": "dimension", "$value": f"{v}px"}
             for k, v in typo["size"].items()}
    weights = {k: {"$type": "fontWeight", "$value": v}
               for k, v in typo["weight"].items()}

    e = motion["ease"]
    motion_out = {
        "$description": "One curve, shared by the shell, the compositor and the lock screen.",
        "ease": {"$type": "cubicBezier", "$value": e},
        "duration": {k: {"$type": "duration", "$value": f"{v}ms"}
                     for k, v in motion["duration"].items()},
        "stagger": {"$type": "duration", "$value": f'{motion["stagger"]}ms'},
    }

    ansi = {f"ansi-{i}": {"$type": "color", "$value": c}
            for i, c in enumerate(term["ansi"])}
    terminal = {
        "$description": "The dark surface family. Editors, Spotify and the terminal all "
                        "derive from here: surfaces you work IN are dark, chrome you work "
                        "WITH is light.",
        "background": {"$type": "color", "$value": term["background"]},
        "foreground": {"$type": "color", "$value": term["foreground"]},
        "cursor": {"$type": "color", "$value": term["cursor"]},
    }
    terminal.update(ansi)

    doc = {
        "$description": (
            "Generated from design/tokens.json — the single source for a Hyprland "
            "desktop, its terminal, editor, login screen and Spotify. Edit the source, "
            "not this file."
        ),
        "color": group("Light XMB. Zero warm hues; the absence of orange and amber is "
                       "load-bearing.", colors),
        "space": group("Strict 4px grid.", spacing),
        "radius": group("Chrome uses 8 — the XMB material is more angular than glass.", radii),
        "type": {
            "$description": "Geist, one family. Weight never exceeds 400: hierarchy comes "
                            "from size, opacity, tracking and glow.",
            "family": {"$type": "fontFamily", "$value": typo["families"]},
            "size": sizes,
            "weight": weights,
            "tracking": {"$type": "number", "$value": typo["trackingEm"]},
        },
        "motion": motion_out,
        "terminal": terminal,
    }
    return json.dumps(doc, indent=2) + "\n"


def render_tokens_ts(t: dict) -> str:
    """A typed module, so a web project consumes the same tokens as the desktop.

    `as const` throughout: the point of importing tokens rather than retyping
    them is that a typo becomes a type error instead of a slightly-wrong blue.
    """
    color, space, radius = t["color"], t["space"], t["radius"]
    typo, motion, term = t["type"], t["motion"], t["terminal"]

    def obj(d: dict, fmt=lambda v: json.dumps(v)) -> str:
        return "{\n" + "".join(
            f"  {json.dumps(k)}: {fmt(v)},\n" for k, v in d.items()) + "}"

    e = motion["ease"]
    return f"""// {BANNER}
//
// The same tokens the desktop is built from. Import these rather than retyping
// a hex: with `as const`, a wrong name is a type error instead of a slightly
// wrong blue that nobody notices for a month.

export const color = {obj(color)} as const;

export const space = {obj(space)} as const;

export const radius = {obj(radius)} as const;

export const type = {{
  family: {json.dumps(typo["families"])},
  size: {obj(typo["size"])},
  weight: {obj(typo["weight"])},
  trackingEm: {typo["trackingEm"]},
}} as const;

export const motion = {{
  // Feed straight into a CSS transition; the shell and compositor use the same.
  ease: "cubic-bezier({e[0]}, {e[1]}, {e[2]}, {e[3]})",
  bezier: {json.dumps(e)},
  duration: {obj(motion["duration"])},
  stagger: {motion["stagger"]},
}} as const;

// Surfaces you work IN are dark; chrome you work WITH is light. This is the
// dark family — editors, Spotify and the terminal all derive from it.
export const terminal = {{
  background: {json.dumps(term["background"])},
  foreground: {json.dumps(term["foreground"])},
  cursor: {json.dumps(term["cursor"])},
  ansi: {json.dumps(term["ansi"])},
}} as const;

export type ColorToken = keyof typeof color;
export type SpaceToken = keyof typeof space;
export type RadiusToken = keyof typeof radius;

export const tokens = {{ color, space, radius, type, motion, terminal }} as const;
export default tokens;
"""


# --------------------------------------------------------------------------
# cava
# --------------------------------------------------------------------------

def render_cava(t: dict) -> str:
    """cava's config, coloured from the TERMINAL block.

    cava draws inside the terminal, so it belongs to the terminal's palette for
    the same reason the editor does — and the gradient is the wave field stood
    on end: deep navy at the base rising to ANSI bright blue and cyan.

    **`background` is deliberately left at default.** Setting it would paint an
    opaque rectangle over the terminal's own background and destroy the
    translucency and blur that docs/CHANGES.md spent a tuning pass measuring
    (light bg at 0.68 washed out; dark bg at 0.62 plus blur brightness 0.45
    reaches 8.71:1). A visualiser is not worth losing that.

    The whole file is generated because the config it replaces set **nothing** —
    six non-comment lines, all of them section headers. There was no hand-tuning
    to lose, and cava has no include directive, so a ghostty-style split into a
    generated theme file is not available.
    """
    term = t["terminal"]
    ansi = term["ansi"]
    bg = term["background"]

    # Bottom to top, blue rising to cyan.
    #
    # cava maps the gradient to the HEIGHT OF THE SCREEN, not to each bar, so a
    # bar that only reaches a third of the way up never shows anything past the
    # third stop. The first version started two steps off the terminal
    # background for subtlety and the result was almost invisible: in a tall
    # terminal the bars sat entirely inside the dark end of the ramp and read
    # as slightly-lighter background.
    #
    # So the ramp starts at a colour that already stands off the background and
    # climbs from there. Every bar height gets a legible colour, and a peak
    # still resolves to cyan.
    ramp = [
        ansi[4],                        # ANSI blue
        _mix(ansi[4], ansi[12], 0.5),
        ansi[12],                       # ANSI bright blue
        _mix(ansi[12], ansi[14], 0.5),
        ansi[14],                       # ANSI bright cyan
    ]

    L = [
        f"; {BANNER}",
        ";",
        "; Only the values this desktop has an opinion about are set; everything",
        "; else is left absent so cava keeps its own defaults.",
        "",
        "[input]",
        "",
        "; Without this cava captures nothing and draws an empty window — which",
        "; looks exactly like a broken theme. `auto` resolves to the default",
        "; sink's monitor, so it follows the output device instead of naming one:",
        "; this desk has nine sources and the default moves between headphones,",
        "; speakers and SPDIF.",
        "method = pulse",
        "source = auto",
        "",
        "[general]",
        "",
        "; Same value as cava's own default, stated explicitly because the",
        "; shell animates at 60 too and this should track it if that changes.",
        "framerate = 60",
        "autosens = 1",
        "",
        "[color]",
        "",
        "; Left at the terminal's own background on purpose: setting it here",
        "; paints over the translucency and blur the terminal is tuned for.",
        "; background = default",
        f"foreground = '{ansi[12]}'",
        "",
        "gradient = 1",
    ]
    for i, c in enumerate(ramp, start=1):
        L.append(f"gradient_color_{i} = '{c}'")
    L.append("")
    return "\n".join(L)


# --------------------------------------------------------------------------
# GTK / libadwaita
# --------------------------------------------------------------------------

def render_gtk(t: dict, adwaita: bool) -> str:
    """@define-color overrides for GTK3 and GTK4/libadwaita.

    libadwaita does not honour arbitrary GTK themes — the whole point of it is
    that apps look the same everywhere — but it *does* read named colours from
    ~/.config/gtk-4.0/gtk.css. Overriding those is the supported way to retheme
    Nautilus and friends without fighting the toolkit.

    GTK3 apps read a much smaller set of names, hence the two variants.

    These surfaces are DARK while the shell chrome is light. That is the same
    figure/ground call the terminal already makes: a file manager is a window you
    look *into*, and the bar is a surface you look *at*. The ramp is `dark` in
    tokens.json, anchored on terminal.background so the terminal and Nautilus are
    the same dark rather than two darks that nearly match.

    Note that libadwaita picks its light or dark variant from
    org.gnome.desktop.interface color-scheme, but these @define-color values
    override BOTH variants — which is why Nautilus was rendering light even with
    color-scheme already set to prefer-dark. The named colours won.
    """
    c = t["dark"]
    term = t["terminal"]

    # ANSI red/green/yellow, reused for destructive/success/warning. Same
    # reasoning as the terminal: these are semantics, not decoration — a delete
    # confirmation that is not red is a worse dialog, palette purity aside.
    red, green, yellow = term["ansi"][1], term["ansi"][2], term["ansi"][3]

    L = [
        f"/* {BANNER} */",
        "",
    ]

    if adwaita:
        L += [
            "/* libadwaita named palette. Anything not listed here keeps its",
            "   upstream value, which is deliberate — overriding the full set",
            "   produces a theme that breaks on every libadwaita release. */",
            "",
            f'@define-color window_bg_color {c["bg-0"]};',
            f'@define-color window_fg_color {c["text-1"]};',
            f'@define-color view_bg_color {c["bg-1"]};',
            f'@define-color view_fg_color {c["text-1"]};',
            f'@define-color headerbar_bg_color {c["bg-1"]};',
            f'@define-color headerbar_fg_color {c["text-1"]};',
            f'@define-color headerbar_border_color {c["border"]};',
            f'@define-color headerbar_backdrop_color {c["bg-0"]};',
            f'@define-color sidebar_bg_color {c["bg-2"]};',
            f'@define-color sidebar_fg_color {c["text-1"]};',
            f'@define-color sidebar_backdrop_color {c["bg-0"]};',
            f'@define-color secondary_sidebar_bg_color {c["bg-2"]};',
            f'@define-color secondary_sidebar_fg_color {c["text-1"]};',
            f'@define-color card_bg_color {c["bg-1"]};',
            f'@define-color card_fg_color {c["text-1"]};',
            f'@define-color dialog_bg_color {c["bg-0"]};',
            f'@define-color dialog_fg_color {c["text-1"]};',
            f'@define-color popover_bg_color {c["bg-1"]};',
            f'@define-color popover_fg_color {c["text-1"]};',
            f'@define-color thumbnail_bg_color {c["bg-1"]};',
            f'@define-color thumbnail_fg_color {c["text-1"]};',
            "",
            f'@define-color accent_bg_color {c["accent"]};',
            f'@define-color accent_fg_color {c["accent-ink"]};',
            "/* accent_color is TEXT, so on these dark surfaces it needs the",
            "   LIGHT step. color.accent (#3478c4) is tuned for near-white and",
            "   falls below AA as link text on #14293f. */",
            f'@define-color accent_color {c["accent"]};',
            "",
            f'@define-color destructive_bg_color {red};',
            f'@define-color destructive_fg_color {c["accent-ink"]};',
            f'@define-color destructive_color {red};',
            f'@define-color success_bg_color {green};',
            f'@define-color success_fg_color {c["accent-ink"]};',
            f'@define-color success_color {green};',
            f'@define-color warning_bg_color {yellow};',
            f'@define-color warning_fg_color {c["accent-ink"]};',
            f'@define-color warning_color {yellow};',
            f'@define-color error_bg_color {red};',
            f'@define-color error_fg_color {c["accent-ink"]};',
            f'@define-color error_color {red};',
            "",
            f'@define-color borders {c["border"]};',
        ]
    else:
        L += [
            "/* GTK3 reads a much smaller set of names than libadwaita. */",
            "",
            f'@define-color theme_bg_color {c["bg-0"]};',
            f'@define-color theme_fg_color {c["text-1"]};',
            f'@define-color theme_base_color {c["bg-1"]};',
            f'@define-color theme_text_color {c["text-1"]};',
            f'@define-color theme_selected_bg_color {c["accent"]};',
            f'@define-color theme_selected_fg_color {c["accent-ink"]};',
            f'@define-color insensitive_bg_color {c["bg-0"]};',
            f'@define-color insensitive_fg_color {c["text-2"]};',
            f'@define-color borders {c["border"]};',
            f'@define-color warning_color {yellow};',
            f'@define-color error_color {red};',
            f'@define-color success_color {green};',
        ]

    L.append("")
    return "\n".join(L)


# --------------------------------------------------------------------------
# ghostty
# --------------------------------------------------------------------------

def render_ghostty(t: dict) -> str:
    term = t["terminal"]
    L = [
        f"# {BANNER}",
        "#",
        "# Included by ghostty/config via `config-file = gelo-theme`.",
        "",
        f'background = {term["background"].lstrip("#")}',
        f'foreground = {term["foreground"].lstrip("#")}',
        f'cursor-color = {term["cursor"].lstrip("#")}',
        f'selection-background = {term["selectionBackground"].lstrip("#")}',
        f'selection-foreground = {term["selectionForeground"].lstrip("#")}',
        "",
        f'background-opacity = {term["opacity"]}',
        f'background-blur = {term["blur"]}',
        "",
        "# ANSI 0-15. See the note in design/tokens.json about why 1/3/9/11 are",
        "# genuinely warm in a palette that otherwise forbids it.",
    ]
    for i, c in enumerate(term["ansi"]):
        L.append(f'palette = {i}={c}')
    L.append("")
    return "\n".join(L)


# --------------------------------------------------------------------------
# hyprlang
# --------------------------------------------------------------------------

def render_hypr(t: dict) -> str:
    L = [
        f"# {BANNER}",
        "#",
        "# Sourced by hyprland.conf and hyprlock.conf:  source = ~/.config/hypr/tokens.conf",
        "# Hyprland wants bare hex without the leading '#', so colours are emitted twice:",
        "#   $x        -> rgb(rrggbb)     for opaque use",
        "#   $x_rgba   -> rgba(rrggbbaa)  for border/blur properties that require alpha",
        "",
        "# --- colour ---",
    ]
    for k, v in t["color"].items():
        plain, rgba = hypr_color(v)
        L.append(f"${snake(k)} = {plain}")
        L.append(f"${snake(k)}_rgba = {rgba}")

    L += ["", "# --- spacing (4px grid) ---"]
    for k, v in t["space"].items():
        L.append(f"$space_{k} = {v}")

    L += ["", "# --- radius ---"]
    for k, v in t["radius"].items():
        L.append(f"$radius_{k} = {v}")

    L += ["", "# --- type ---"]
    L.append(f'$font_display = {t["type"]["display"]}')
    for k, v in t["type"]["size"].items():
        L.append(f"$text_{k} = {v}")

    L += ["", "# --- motion ---"]
    e = t["motion"]["ease"]
    L.append(f"# expo-out, matching --ease everywhere else in the system")
    L.append(f"bezier = ease, {e[0]}, {e[1]}, {e[2]}, {e[3]}")
    for k, v in t["motion"]["duration"].items():
        # hyprland animation speeds are in deciseconds
        L.append(f"$dur_{k} = {round(v / 100)}")

    L += ["", "# --- chrome ---"]
    c = t["material"]["chrome"]
    L.append(f'$chrome_opacity = {c["surfaceOpacity"]}')
    L.append(f'$chrome_radius = {c["radius"]}')
    L.append(f'$chrome_shadow = {c["shadowRadius"]}')
    L.append("")
    return "\n".join(L)


# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Shared QML components
# --------------------------------------------------------------------------
# The shell and the SDDM theme are separate QML roots — the login theme is
# installed to /usr/share/sddm/themes and has to be self-contained, so it cannot
# import anything out of ~/.config. Rather than keep two copies of the chrome
# material that quietly drift apart, the component has one source and is copied
# into each root with its Theme import rewritten for that location.

SHARED_COMPONENTS = {
    "Chrome.qml": {
        ROOT / "quickshell/gelo/Components/Chrome.qml": 'root:/Theme',
        ROOT / "sddm/themes/gelo-liquid/Components/Chrome.qml": '../Theme',
    },
    "Glow.qml": {
        ROOT / "quickshell/gelo/Components/Glow.qml": 'root:/Theme',
        ROOT / "sddm/themes/gelo-liquid/Components/Glow.qml": '../Theme',
    },
    "Icon.qml": {
        ROOT / "quickshell/gelo/Components/Icon.qml": 'root:/Theme',
        ROOT / "sddm/themes/gelo-liquid/Components/Icon.qml": '../Theme',
    },
    "Reflection.qml": {
        ROOT / "quickshell/gelo/Components/Reflection.qml": 'root:/Theme',
        ROOT / "sddm/themes/gelo-liquid/Components/Reflection.qml": '../Theme',
    },
}


# Shaders are copied verbatim into each root for the same reason — the SDDM
# theme cannot reach into ~/.config. The .frag is the source; the .qsb bundles
# next to each copy are produced by design/build-shaders.sh.
SHARED_SHADERS = {
    "xmb.frag": [
        ROOT / "sddm/themes/gelo-liquid/Shaders/xmb.frag",
        ROOT / "quickshell/gelo/Shaders/xmb.frag",
    ],
}


# Our own icon set. Qt's icon-theme lookup resolves application icons fine but
# returns nothing for Adwaita's symbolic names — its index.theme only indexes
# 16x16/scalable/symbolic and Qt finds none of the status glyphs. Owning ~17
# small SVGs removes that dependency entirely and lets the icons match the
# geometric type rather than GNOME's house style.
def render_icons() -> dict:
    out = {}
    for src in sorted((ROOT / "design/icons").glob("*.svg")):
        body = src.read_text()
        out[ROOT / "quickshell/gelo/icons" / src.name] = body
        out[ROOT / "sddm/themes/gelo-liquid/icons" / src.name] = body
    return out


def render_shaders() -> dict:
    out = {}
    for name, targets in SHARED_SHADERS.items():
        source = (ROOT / "design/shaders" / name).read_text()
        for path in targets:
            out[path] = source
    return out


def own_icons_literal() -> str:
    """The names design/icons serves, as a QML array literal."""
    names = sorted(p.stem for p in (ROOT / "design/icons").glob("*.svg"))
    return ", ".join(f'"{n}"' for n in names)


def render_components() -> dict:
    out = {}
    for name, targets in SHARED_COMPONENTS.items():
        source = (ROOT / "design/qml" / name).read_text()
        # //! lines are notes to whoever edits the source; they are meaningless
        # (and actively confusing) in a generated do-not-edit copy.
        source = "\n".join(
            l for l in source.splitlines() if not l.lstrip().startswith("//!")
        ) + "\n"

        for path, theme_import in targets.items():
            body = source.replace("@THEME@", theme_import)
            icon_root = "root:/icons/" if "quickshell" in str(path) else "../icons/"
            body = body.replace("@ICONROOT@", icon_root)
            # Icon.qml has to know which names it serves itself rather than
            # handing to the system icon theme, and that list used to be typed
            # out by hand next to a directory of SVGs. Dropping a new icon into
            # design/icons was therefore not enough to make it render: it fell
            # through to the theme lookup, which returns empty for every status
            # glyph on this machine (docs/handoff.md), so the icon silently did
            # not appear. Generate it from the directory instead.
            body = body.replace("@OWNICONS@", own_icons_literal())
            out[path] = f"// {BANNER.replace('design/tokens.json', 'design/qml/' + name)}\n{body}"
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="fail if any output is stale")
    ap.add_argument("--audit", action="store_true",
                    help="print the contrast table; fail if any pair is below its threshold")
    args = ap.parse_args()

    tokens = strip_comments(json.loads(TOKENS.read_text()))

    if args.audit:
        return 1 if run_audit(tokens) else 0

    qml = render_qml(tokens)
    outputs = {
        ROOT / "quickshell/gelo/Theme/Tokens.qml": qml,
        ROOT / "quickshell/gelo/Theme/qmldir": render_qmldir(),
        ROOT / "sddm/themes/gelo-liquid/Theme/Tokens.qml": qml,
        ROOT / "sddm/themes/gelo-liquid/Theme/qmldir": render_qmldir(),
        ROOT / "design/tokens.css": render_css(tokens),
        ROOT / "hypr/tokens.conf": render_hypr(tokens),
        ROOT / "ghostty/gelo-theme": render_ghostty(tokens),
        ROOT / "gtk-4.0/gtk.css": render_gtk(tokens, adwaita=True),
        ROOT / "gtk-3.0/gtk.css": render_gtk(tokens, adwaita=False),
        ROOT / "vscode/gelo-xmb/themes/gelo-xmb-color-theme.json": render_vscode(tokens),
        ROOT / "vscode/gelo-xmb/package.json": render_vscode_manifest(tokens),
        ROOT / "design/tokens.dtcg.json": render_dtcg(tokens),
        ROOT / "design/tokens.ts": render_tokens_ts(tokens),
        ROOT / "cava/config": render_cava(tokens),
        ROOT / "spicetify/gelo-xmb/color.ini": render_spicetify(tokens),
        ROOT / "spicetify/gelo-xmb/user.css": render_spicetify_css(tokens),
        ROOT / "spicetify/gelo-xmb/theme.js": render_spicetify_js(tokens),
    }
    outputs.update(render_site(tokens))
    outputs.update(render_components())
    outputs.update(render_shaders())
    outputs.update(render_icons())

    stale = []
    for path, content in outputs.items():
        current = path.read_text() if path.exists() else None
        if current == content:
            continue
        stale.append(path)
        if not args.check:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)

    rel = lambda p: p.relative_to(ROOT)

    if args.check:
        if stale:
            print("stale token outputs:", file=sys.stderr)
            for p in stale:
                print(f"  {rel(p)}", file=sys.stderr)
            print("\nrun: design/build-tokens.py", file=sys.stderr)
            return 1
        print(f"all {len(outputs)} token outputs up to date")
        return 0

    if stale:
        for p in stale:
            print(f"wrote {rel(p)}")
    else:
        print(f"all {len(outputs)} token outputs already up to date")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
