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
    return out


def snake(name: str) -> str:
    """accent-dim -> accent_dim (hyprlang variables tolerate underscores, not hyphens)."""
    return name.replace("-", "_")


def qml_num(v) -> str:
    return str(v) if isinstance(v, int) else repr(float(v))


# --------------------------------------------------------------------------
# QML singleton
# --------------------------------------------------------------------------

def render_qml(t: dict) -> str:
    color, space, radius = t["color"], t["space"], t["radius"]
    typo, motion, mat = t["type"], t["motion"], t["material"]
    glass, blob = mat["glass"], mat["blob"]

    L: list[str] = [
        f"// {BANNER}",
        "pragma Singleton",
        "",
        "import QtQuick",
        "",
        "QtObject {",
        "    id: root",
        "",
        "    // Returns `c` at alpha `a`. The glass material is defined as a base colour",
        "    // plus an opacity, so nearly every surface in the system goes through here.",
        "    function alpha(c, a) {",
        "        return Qt.rgba(c.r, c.g, c.b, a);",
        "    }",
        "",
        "    readonly property QtObject color: QtObject {",
    ]
    for k, v in color.items():
        L.append(f'        readonly property color {camel(k)}: "{v}"')
    L += ["    }", "", "    readonly property QtObject space: QtObject {"]
    for k, v in space.items():
        L.append(f"        readonly property int {k}: {v}")
    L += ["    }", "", "    readonly property QtObject radius: QtObject {"]
    for k, v in radius.items():
        L.append(f"        readonly property int {k}: {v}")
    L += [
        "    }",
        "",
        "    readonly property QtObject typography: QtObject {",
        f'        readonly property string mono: "{typo["mono"]}"',
        f'        readonly property string sans: "{typo["sans"]}"',
        "",
        "        readonly property QtObject size: QtObject {",
    ]
    for k, v in typo["size"].items():
        L.append(f"            readonly property int {k}: {v}")
    L += ["        }", "", "        readonly property QtObject weight: QtObject {"]
    for k, v in typo["weight"].items():
        L.append(f"            readonly property int {k}: {v}")
    L += ["        }", "", "        readonly property QtObject letterSpacing: QtObject {"]
    for k, v in typo["letterSpacing"].items():
        L.append(f"            readonly property real {k}: {qml_num(v)}")
    L += ["        }", "    }", "", "    readonly property QtObject motion: QtObject {"]

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
        "        readonly property QtObject glass: QtObject {",
    ]
    for k, v in glass.items():
        kind = "int" if isinstance(v, int) else "real"
        L.append(f"            readonly property {kind} {k}: {qml_num(v)}")
    L += [
        "",
        "            // Derived surfaces — the actual paintable values components bind to.",
        "            readonly property color background: root.alpha(root.color.bg1, backgroundOpacity)",
        "            readonly property color stroke: root.alpha(root.color.border, borderOpacity)",
        "            readonly property color specular: root.alpha(root.color.text1, specularOpacity)",
        "            readonly property color shadow: root.alpha(root.color.bg0, shadowOpacity)",
        "        }",
        "",
        "        readonly property QtObject blob: QtObject {",
    ]
    for k, v in blob.items():
        kind = "int" if isinstance(v, int) else "real"
        L.append(f"            readonly property {kind} {k}: {qml_num(v)}")
    L += ["        }", "    }", "}", ""]
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
    L.append(f'  --font-mono: "{t["type"]["mono"]}", monospace;')
    L.append(f'  --font-sans: "{t["type"]["sans"]}", sans-serif;')
    for k, v in t["type"]["size"].items():
        L.append(f"  --text-{k}: {v}px;")
    for k, v in t["type"]["weight"].items():
        L.append(f"  --weight-{k}: {v};")

    L.append("")
    L.append("  /* motion */")
    L.append(f"  --ease: cubic-bezier({e[0]}, {e[1]}, {e[2]}, {e[3]});")
    for k, v in t["motion"]["duration"].items():
        L.append(f"  --dur-{k}: {v}ms;")
    L.append(f'  --stagger: {t["motion"]["stagger"]}ms;')

    L.append("")
    L.append("  /* liquid-glass material */")
    for k, v in t["material"]["glass"].items():
        unit = "px" if k.endswith(("Radius", "Height", "OffsetY")) else ""
        L.append(f"  --glass-{k}: {v}{unit};")

    L += ["}", ""]
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
        h = v.lstrip("#")
        L.append(f"${snake(k)} = rgb({h})")
        L.append(f"${snake(k)}_rgba = rgba({h}ff)")

    L += ["", "# --- spacing (4px grid) ---"]
    for k, v in t["space"].items():
        L.append(f"$space_{k} = {v}")

    L += ["", "# --- radius ---"]
    for k, v in t["radius"].items():
        L.append(f"$radius_{k} = {v}")

    L += ["", "# --- type ---"]
    L.append(f'$font_mono = {t["type"]["mono"]}')
    L.append(f'$font_sans = {t["type"]["sans"]}')
    for k, v in t["type"]["size"].items():
        L.append(f"$text_{k} = {v}")

    L += ["", "# --- motion ---"]
    e = t["motion"]["ease"]
    L.append(f"# expo-out, matching --ease everywhere else in the system")
    L.append(f"bezier = ease, {e[0]}, {e[1]}, {e[2]}, {e[3]}")
    for k, v in t["motion"]["duration"].items():
        # hyprland animation speeds are in deciseconds
        L.append(f"$dur_{k} = {round(v / 100)}")

    L += ["", "# --- glass ---"]
    g = t["material"]["glass"]
    L.append(f'$glass_blur = {g["blurRadius"]}')
    L.append(f'$glass_opacity = {g["backgroundOpacity"]}')
    L.append(f'$glass_radius = {g["radiusRest"]}')
    L.append("")
    return "\n".join(L)


# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# Shared QML components
# --------------------------------------------------------------------------
# The shell and the SDDM theme are separate QML roots — the login theme is
# installed to /usr/share/sddm/themes and has to be self-contained, so it cannot
# import anything out of ~/.config. Rather than keep two copies of the glass
# material that quietly drift apart, the component has one source and is copied
# into each root with its Theme import rewritten for that location.

SHARED_COMPONENTS = {
    "Glass.qml": {
        ROOT / "quickshell/gelo/Components/Glass.qml": 'root:/Theme',
        ROOT / "sddm/themes/gelo-liquid/Components/Glass.qml": '../Theme',
    },
}


# Shaders are copied verbatim into each root for the same reason — the SDDM
# theme cannot reach into ~/.config. The .frag is the source; the .qsb bundles
# next to each copy are produced by design/build-shaders.sh.
SHARED_SHADERS = {
    "fluid.frag": [
        ROOT / "sddm/themes/gelo-liquid/Shaders/fluid.frag",
        ROOT / "quickshell/gelo/Shaders/fluid.frag",
    ],
}


def render_shaders() -> dict:
    out = {}
    for name, targets in SHARED_SHADERS.items():
        source = (ROOT / "design/shaders" / name).read_text()
        for path in targets:
            out[path] = source
    return out


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
            out[path] = f"// {BANNER.replace('design/tokens.json', 'design/qml/' + name)}\n{body}"
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="fail if any output is stale")
    args = ap.parse_args()

    tokens = strip_comments(json.loads(TOKENS.read_text()))

    qml = render_qml(tokens)
    outputs = {
        ROOT / "quickshell/gelo/Theme/Tokens.qml": qml,
        ROOT / "quickshell/gelo/Theme/qmldir": render_qmldir(),
        ROOT / "sddm/themes/gelo-liquid/Theme/Tokens.qml": qml,
        ROOT / "sddm/themes/gelo-liquid/Theme/qmldir": render_qmldir(),
        ROOT / "design/tokens.css": render_css(tokens),
        ROOT / "hypr/tokens.conf": render_hypr(tokens),
    }
    outputs.update(render_components())
    outputs.update(render_shaders())

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
