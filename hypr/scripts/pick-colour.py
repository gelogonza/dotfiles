#!/usr/bin/env python3
"""Pick a colour off the screen and say which design token it is.

`hyprpicker` already puts a hex on the clipboard. The part worth building is the
second half: when you are maintaining a palette, the question is almost never
"what colour is that pixel" — it is **"is that one of mine, and if not, how far
off is it?"** Nothing off-the-shelf answers that, because the answer depends on
design/tokens.json.

Matching is done in CIELAB with **CIEDE2000**, not by RGB distance, and not by
the simpler CIE76. That is not decoration on this palette in particular: it is
almost entirely saturated blue, and RGB distance is badly non-perceptual exactly
there — two blues a long way apart numerically can be indistinguishable, while a
small numeric step across a hue boundary is obvious. CIE76 has the same problem
in the blue region, which is the well-known reason CIEDE2000 exists.

Thresholds come from the same literature:

    dE < 1.0    the eye cannot tell them apart at all -> "is"
    dE < 2.3    the just-noticeable difference        -> "matches"
    otherwise   report the nearest and the distance   -> "nearest"

Usage: pick-colour.py
"""

from __future__ import annotations

import json
import math
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TOKENS = ROOT / "design" / "tokens.json"


def notify(summary: str, body: str = "", *, urgent: bool = False,
           image: str | None = None, actions: list[str] | None = None) -> str:
    cmd = ["notify-send", "-a", "Colour"]
    if urgent:
        cmd += ["-u", "critical"]
    if image:
        cmd += [f"--hint=string:image-path:{image}"]
    for a in actions or []:
        cmd += ["-A", a]
    cmd += [summary, body]
    try:
        return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()
    except FileNotFoundError:
        print(f"{summary}: {body}")
        return ""


# --- colour maths ---------------------------------------------------------

def srgb_to_lab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    def lin(c: float) -> float:
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (lin(v) for v in rgb)
    # sRGB D65 -> XYZ, then XYZ -> Lab against the D65 white point.
    x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
    y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b) / 1.00000
    z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883

    def f(t: float) -> float:
        return t ** (1 / 3) if t > 216 / 24389 else (841 / 108) * t + 4 / 29

    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def ciede2000(a: tuple[float, float, float], b: tuple[float, float, float]) -> float:
    """Perceptual distance. The blue-region correction is the whole reason
    this is here rather than a plain Euclidean distance in Lab."""
    l1, a1, b1 = a
    l2, a2, b2 = b
    c1 = math.hypot(a1, b1)
    c2 = math.hypot(a2, b2)
    cbar = (c1 + c2) / 2
    g = 0.5 * (1 - math.sqrt(cbar ** 7 / (cbar ** 7 + 25 ** 7))) if cbar else 0.5
    a1p, a2p = (1 + g) * a1, (1 + g) * a2
    c1p, c2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360 if (a1p or b1) else 0.0
    h2p = math.degrees(math.atan2(b2, a2p)) % 360 if (a2p or b2) else 0.0

    dlp = l2 - l1
    dcp = c2p - c1p
    if c1p * c2p == 0:
        dhp = 0.0
    elif abs(h2p - h1p) <= 180:
        dhp = h2p - h1p
    else:
        dhp = h2p - h1p - 360 if h2p > h1p else h2p - h1p + 360
    dHp = 2 * math.sqrt(c1p * c2p) * math.sin(math.radians(dhp) / 2)

    lbar = (l1 + l2) / 2
    cbarp = (c1p + c2p) / 2
    if c1p * c2p == 0:
        hbarp = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hbarp = (h1p + h2p) / 2
    elif h1p + h2p < 360:
        hbarp = (h1p + h2p + 360) / 2
    else:
        hbarp = (h1p + h2p - 360) / 2

    t = (1 - 0.17 * math.cos(math.radians(hbarp - 30))
         + 0.24 * math.cos(math.radians(2 * hbarp))
         + 0.32 * math.cos(math.radians(3 * hbarp + 6))
         - 0.20 * math.cos(math.radians(4 * hbarp - 63)))
    dtheta = 30 * math.exp(-(((hbarp - 275) / 25) ** 2))
    rc = 2 * math.sqrt(cbarp ** 7 / (cbarp ** 7 + 25 ** 7)) if cbarp else 0.0
    sl = 1 + (0.015 * (lbar - 50) ** 2) / math.sqrt(20 + (lbar - 50) ** 2)
    sc = 1 + 0.045 * cbarp
    sh = 1 + 0.015 * cbarp * t
    rt = -math.sin(math.radians(2 * dtheta)) * rc

    return math.sqrt((dlp / sl) ** 2 + (dcp / sc) ** 2 + (dHp / sh) ** 2
                     + rt * (dcp / sc) * (dHp / sh))


def parse_hex(value: str) -> tuple[int, int, int] | None:
    h = value.lstrip("#")
    if len(h) not in (6, 8) or any(c not in "0123456789abcdefABCDEF" for c in h):
        return None
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]


def collect_tokens(node, path: str = "") -> list[tuple[str, str, tuple[int, int, int]]]:
    """Every hex-looking value in the token source, with a readable name.

    Walking generically rather than naming the groups means a colour added to
    tokens.json is matchable without touching this file.
    """
    out: list[tuple[str, str, tuple[int, int, int]]] = []
    if isinstance(node, dict):
        for k, v in node.items():
            if k.startswith("$"):
                continue
            out += collect_tokens(v, f"{path}.{k}" if path else k)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            out += collect_tokens(v, f"{path}[{i}]")
    elif isinstance(node, str):
        rgb = parse_hex(node)
        if rgb:
            out.append((path, node, rgb))
    return out


def main() -> int:
    if not TOKENS.exists():
        notify("Colour", f"No token source at {TOKENS}", urgent=True)
        return 1

    try:
        picked = subprocess.run(
            ["hyprpicker", "-f", "hex", "-q", "-n"],
            capture_output=True, text=True, timeout=120).stdout.strip()
    except FileNotFoundError:
        notify("Colour", "hyprpicker is not installed.", urgent=True)
        return 1
    except subprocess.TimeoutExpired:
        return 0

    rgb = parse_hex(picked)
    if not rgb:
        return 0                      # cancelled with Escape, which is not an error

    hexv = "#" + "".join(f"{c:02x}" for c in rgb)
    subprocess.run(["wl-copy", hexv], check=False)

    lab = srgb_to_lab(rgb)
    matches = sorted(
        ((ciede2000(lab, srgb_to_lab(t[2])), t) for t in collect_tokens(json.load(TOKENS.open()))),
        key=lambda m: m[0])

    if matches:
        dist, (name, raw, _) = matches[0]
        if dist < 1.0:
            verdict = f"is {name}"
        elif dist < 2.3:
            verdict = f"matches {name}"
        else:
            verdict = f"nearest {name} {raw}  ·  ΔE {dist:.1f}"
        runner = ""
        if len(matches) > 1 and dist >= 1.0:
            d2, (n2, _, _) = matches[1]
            runner = f"\nthen {n2}  ·  ΔE {d2:.1f}"
    else:
        name, verdict, runner = "", "no colours in the token source", ""

    # A swatch, so the notification shows the colour rather than describing it.
    swatch = None
    try:
        fd, swatch = tempfile.mkstemp(prefix="gelo-colour-", suffix=".png")
        os.close(fd)
        subprocess.run(["magick", "-size", "128x128", f"xc:{hexv}", swatch],
                       check=True, capture_output=True)
    except Exception:
        swatch = None

    r, g, b = rgb
    chosen = notify(
        f"{hexv}   {verdict}",
        f"rgb({r}, {g}, {b}){runner}",
        image=swatch,
        actions=["hex=Copy hex", "rgb=Copy rgb", "token=Copy token"])

    if chosen == "rgb":
        subprocess.run(["wl-copy", f"rgb({r}, {g}, {b})"], check=False)
    elif chosen == "token" and name:
        subprocess.run(["wl-copy", name], check=False)
    elif chosen == "hex":
        subprocess.run(["wl-copy", hexv], check=False)

    if swatch and os.path.exists(swatch):
        os.unlink(swatch)
    return 0


if __name__ == "__main__":
    sys.exit(main())
