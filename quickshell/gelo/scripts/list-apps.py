#!/usr/bin/env python3
"""Index XDG desktop entries as JSON for the launcher.

Quickshell 0.3.0 ships a DesktopEntries singleton, but on this system it returns
an empty model and both byId() and heuristicLookup() return null, so the launcher
builds its own index instead. That turns out to be the better architecture for a
command palette anyway: the palette mixes applications with shell actions, and
owning the index means owning the ranking.

Output: a JSON array on stdout, sorted by name.

    [{"name","exec","icon","comment","categories","terminal","id"}, ...]
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

# Exec field codes (%f %U %i %c %k ...) are launcher-substitution placeholders.
# We launch without arguments, so they must be stripped or the command breaks.
FIELD_CODES = re.compile(r"%[fFuUdDnNickvm]")


def data_dirs() -> list[Path]:
    home = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"

    seen: list[Path] = []
    for d in [home, *dirs.split(":")]:
        if not d:
            continue
        p = Path(d).expanduser() / "applications"
        if p.is_dir() and p not in seen:
            seen.append(p)
    return seen


def parse(path: Path) -> dict | None:
    """Read the [Desktop Entry] group. Returns None for anything unlaunchable."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None

    entry: dict[str, str] = {}
    in_group = False

    for line in text.splitlines():
        line = line.strip()
        if line.startswith("["):
            # Only the main group; [Desktop Action foo] groups are separate verbs.
            in_group = line == "[Desktop Entry]"
            continue
        if not in_group or not line or line.startswith("#"):
            continue
        key, _, value = line.partition("=")
        if not _:
            continue
        key = key.strip()
        # Ignore localised keys (Name[de]) — we want the untranslated default.
        if "[" in key:
            continue
        entry.setdefault(key, value.strip())

    if entry.get("Type") != "Application":
        return None
    if entry.get("NoDisplay", "").lower() == "true":
        return None
    if entry.get("Hidden", "").lower() == "true":
        return None

    name = entry.get("Name")
    exec_line = entry.get("Exec")
    if not name or not exec_line:
        return None

    exec_clean = FIELD_CODES.sub("", exec_line).strip()
    exec_clean = re.sub(r"\s{2,}", " ", exec_clean)
    if not exec_clean:
        return None

    return {
        "id": path.stem,
        "name": name,
        "exec": exec_clean,
        "icon": entry.get("Icon", ""),
        "comment": entry.get("Comment", ""),
        "categories": [c for c in entry.get("Categories", "").split(";") if c],
        "terminal": entry.get("Terminal", "").lower() == "true",
    }


def main() -> int:
    apps: dict[str, dict] = {}

    # Earlier dirs win: ~/.local/share overrides /usr/share for the same id,
    # which is exactly the XDG precedence rule.
    for directory in data_dirs():
        for path in sorted(directory.rglob("*.desktop")):
            item = parse(path)
            if item and item["id"] not in apps:
                apps[item["id"]] = item

    out = sorted(apps.values(), key=lambda a: a["name"].casefold())
    json.dump(out, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
