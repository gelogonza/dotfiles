#!/usr/bin/env python3
"""Generate the accent cursor theme by recolouring an existing XCursor theme.

This is the third and last of the three places the design system permits the
accent to appear (workspace indicator, focused window border, cursor).

WHY RECOLOUR RATHER THAN AUTHOR: a usable cursor theme is ~35 distinct cursors
(resize handles in eight directions, text, crosshair, grab, wait, dnd states...)
across six nominal sizes. Drawing those is a project, and getting one wrong means
an application silently falls back to a different theme mid-interaction. Taking a
complete, well-hinted theme and applying the palette to it is the same result for
a fraction of the risk.

WHY XCURSOR RATHER THAN HYPRCURSOR: XCursor is understood by both Wayland
clients and XWayland. A hyprcursor theme scales better but leaves every XWayland
application on the system default, which is exactly the inconsistency this is
meant to remove.

The output is NOT committed. It is ~12MB of binaries derived from Adwaita
(CC-BY-SA 3.0), and redistributing a recoloured copy inside this repo would drag
the attribution requirements along with it. Run this script instead; it is
deterministic.

    design/build-cursor.py [--source DIR] [--install]

XCursor format, for reference:
    header : "Xcur", header size u32, version u32, ntoc u32
    toc    : ntoc * (type u32, subtype u32, position u32)
    image  : chunk header (36 bytes: size, type, subtype, version,
             width, height, xhot, yhot, delay) then width*height ARGB u32,
             little-endian, alpha-premultiplied.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOKENS = ROOT / "design" / "tokens.json"

CHUNK_IMAGE = 0xFFFD0002
THEME_NAME = "gelo-cursor"

DEFAULT_SOURCE = Path("/usr/share/icons/Adwaita/cursors")
DEFAULT_OUT = Path.home() / ".local/share/icons" / THEME_NAME


def hex_rgb(value: str) -> tuple[int, int, int]:
    h = value.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def recolour_pixels(buf: bytearray, offset: int, count: int,
                    fill: tuple[int, int, int], edge: tuple[int, int, int]) -> None:
    """Map each pixel's luminance onto the fill..edge ramp, preserving alpha.

    The source is black-filled with a white outline, so luminance IS the
    fill/outline discriminator: 0 becomes the accent, 255 stays the outline
    colour, and the antialiased pixels in between interpolate, which keeps the
    edges as smooth as they were.
    """
    fr, fg, fb = fill
    er, eg, eb = edge

    for i in range(count):
        p = offset + i * 4
        v = int.from_bytes(buf[p:p + 4], "little")

        a = (v >> 24) & 0xFF
        if a == 0:
            continue

        r = (v >> 16) & 0xFF
        g = (v >> 8) & 0xFF
        b = v & 0xFF

        # Un-premultiply before measuring luminance, or semi-transparent pixels
        # read as darker than they are and get pushed toward the fill colour.
        scale = 255.0 / a
        lr = min(255.0, r * scale)
        lg = min(255.0, g * scale)
        lb = min(255.0, b * scale)

        lum = (0.2126 * lr + 0.7152 * lg + 0.0722 * lb) / 255.0

        nr = fr + (er - fr) * lum
        ng = fg + (eg - fg) * lum
        nb = fb + (eb - fb) * lum

        # Back to premultiplied.
        pa = a / 255.0
        out = (a << 24) | (int(nr * pa) << 16) | (int(ng * pa) << 8) | int(nb * pa)
        buf[p:p + 4] = out.to_bytes(4, "little")


def convert(path: Path, fill, edge) -> bytes:
    buf = bytearray(path.read_bytes())

    magic, _hsz, _ver, ntoc = struct.unpack_from("<4sIII", buf, 0)
    if magic != b"Xcur":
        raise ValueError(f"{path.name}: not an XCursor file")

    for i in range(ntoc):
        ctype, _sub, pos = struct.unpack_from("<III", buf, 16 + i * 12)
        if ctype != CHUNK_IMAGE:
            continue

        # Patch pixels in place: the recolour never changes the byte length, so
        # the table of contents and every offset in it stay valid.
        _chsz, _ct, _cs, _cv, w, h, _xh, _yh, _delay = struct.unpack_from(
            "<IIIIIIIII", buf, pos)
        recolour_pixels(buf, pos + 36, w * h, fill, edge)

    return bytes(buf)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()

    if not args.source.is_dir():
        print(f"error: cursor source not found: {args.source}", file=sys.stderr)
        print("       install a base theme (e.g. adwaita-cursors) or pass --source",
              file=sys.stderr)
        return 1

    tokens = json.loads(TOKENS.read_text())
    fill = hex_rgb(tokens["color"]["accent"])
    edge = hex_rgb(tokens["color"]["bg-1"])

    cursors = args.out / "cursors"
    if cursors.exists():
        shutil.rmtree(args.out)
    cursors.mkdir(parents=True)

    converted = 0
    linked = 0

    # Symlinks carry the cursor-name aliases every toolkit relies on
    # (`default` -> `left_ptr`, `pointer` -> `hand2`, ...). Recreate them as
    # symlinks rather than copies so the aliasing stays intact.
    for entry in sorted(args.source.iterdir()):
        target = cursors / entry.name

        if entry.is_symlink():
            os.symlink(os.readlink(entry), target)
            linked += 1
            continue
        if not entry.is_file():
            continue

        try:
            target.write_bytes(convert(entry, fill, edge))
            converted += 1
        except ValueError as exc:
            print(f"  skipped {exc}", file=sys.stderr)

    (args.out / "index.theme").write_text(
        "[Icon Theme]\n"
        f"Name={THEME_NAME}\n"
        "Comment=Accent cursor generated by design/build-cursor.py\n"
        "Inherits=Adwaita\n"
    )
    (args.out / "cursor.theme").write_text(
        f"[Icon Theme]\nName={THEME_NAME}\nInherits=Adwaita\n"
    )
    (args.out / "ATTRIBUTION").write_text(
        "Cursor shapes derived from the Adwaita icon theme (GNOME Project),\n"
        "CC-BY-SA 3.0, recoloured to the palette in design/tokens.json.\n"
        f"Source: {args.source}\n"
    )

    print(f"wrote {args.out}")
    print(f"  {converted} cursors recoloured, {linked} aliases linked")
    print(f"  fill  {tokens['color']['accent']}  (accent)")
    print(f"  edge  {tokens['color']['bg-1']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
