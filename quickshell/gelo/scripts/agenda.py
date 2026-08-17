#!/usr/bin/env python3
"""Upcoming events from ICS feeds, as JSON.

Google Calendar and Outlook both publish a **private ICS address** per calendar
(Google: Settings → your calendar → "Secret address in iCal format"; Outlook:
Settings → Calendar → Shared calendars → Publish). That avoids OAuth entirely:
no app registration, no token refresh, no browser round-trip on a desktop that
is meant to work offline-ish.

The cost is that those URLs are **bearer secrets** — anyone with the link reads
your calendar. So they live in

    ~/.config/gelo/calendars.json

which is deliberately *outside* this repo, because the repo is `~/.config` and
is pushed to GitHub. Nothing here prints a URL, including on failure.

    [
      { "name": "personal", "url": "https://calendar.google.com/…/basic.ics" },
      { "name": "school",   "url": "https://outlook.office365.com/…/calendar.ics" }
    ]

Usage: agenda.py [days] [12h|24h]        (default 7, 24h)

The clock format is passed in rather than read from tokens.json: this script is
deliberately free of any path back into the repo, and the caller (Services/
Agenda.qml) already holds the token.
"""

from __future__ import annotations

import json
import os
import re
import sys
import urllib.request
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

try:
    from dateutil import rrule as _rrule
except ImportError:
    _rrule = None

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "gelo" / "calendars.json"
TIMEOUT = 12


def unfold(text: str) -> list[str]:
    """RFC 5545 folds long lines with CRLF + a leading space or tab."""
    out: list[str] = []
    for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
        if raw[:1] in (" ", "\t") and out:
            out[-1] += raw[1:]
        else:
            out.append(raw)
    return out


def parse_dt(value: str, params: dict) -> tuple[datetime, bool]:
    """Returns (aware datetime, is_all_day)."""
    if params.get("VALUE") == "DATE" or re.fullmatch(r"\d{8}", value):
        d = datetime.strptime(value, "%Y%m%d")
        return d.replace(tzinfo=timezone.utc), True

    if value.endswith("Z"):
        return (datetime.strptime(value, "%Y%m%dT%H%M%SZ")
                .replace(tzinfo=timezone.utc), False)

    naive = datetime.strptime(value, "%Y%m%dT%H%M%S")
    tzid = params.get("TZID")
    if tzid:
        try:
            from zoneinfo import ZoneInfo
            return naive.replace(tzinfo=ZoneInfo(tzid)), False
        except Exception:
            pass
    # Floating time: interpret in the local zone, which is what a calendar
    # without a timezone means in practice.
    return naive.astimezone(), False


def parse_events(text: str) -> list[dict]:
    events: list[dict] = []
    current: dict | None = None

    for line in unfold(text):
        if line == "BEGIN:VEVENT":
            current = {}
            continue
        if line == "END:VEVENT":
            if current:
                events.append(current)
            current = None
            continue
        if current is None or ":" not in line:
            continue

        head, value = line.split(":", 1)
        parts = head.split(";")
        name = parts[0].upper()
        params = {}
        for p in parts[1:]:
            if "=" in p:
                k, v = p.split("=", 1)
                params[k.upper()] = v

        if name == "SUMMARY":
            current["summary"] = value.replace("\\,", ",").replace("\\n", " ").strip()
        elif name == "LOCATION":
            current["location"] = value.replace("\\,", ",").strip()
        elif name == "DTSTART":
            current["start"], current["all_day"] = parse_dt(value, params)
        elif name == "DTEND":
            try:
                current["end"], _ = parse_dt(value, params)
            except Exception:
                pass
        elif name == "RRULE":
            current["rrule"] = value
        elif name == "EXDATE":
            ex = current.setdefault("exdates", [])
            for chunk in value.split(","):
                try:
                    ex.append(parse_dt(chunk, params)[0])
                except Exception:
                    pass
        elif name == "STATUS":
            current["status"] = value.upper()

    return events


def clock_format(local: datetime, twelve: bool) -> str:
    """`%I` pads to two digits and there is no portable strip-zero flag that
    works on both glibc (`%-I`) and everywhere else, so do it by hand."""
    if not twelve:
        return local.strftime("%H:%M")
    return local.strftime("%I:%M %p").lstrip("0")


def expand(events: list[dict], window_start: datetime, window_end: datetime,
           twelve: bool = False) -> list[dict]:
    """Occurrences inside the window, recurrences included.

    RRULE is handed to python-dateutil rather than reimplemented: weekly
    classes, monthly billing and "every other Tuesday" are exactly the cases a
    hand-rolled parser gets subtly wrong, and dateutil already has them right.
    Without dateutil the feed still works — recurring events simply do not
    expand, which is a smaller failure than wrong dates.
    """
    out: list[dict] = []

    for e in events:
        start = e.get("start")
        if not start or e.get("status") == "CANCELLED":
            continue

        duration = (e["end"] - start) if e.get("end") else (
            timedelta(days=1) if e.get("all_day") else timedelta(hours=1))

        starts: list[datetime] = []
        if e.get("rrule") and _rrule is not None:
            try:
                rule = _rrule.rrulestr(e["rrule"], dtstart=start)
                starts = list(rule.between(window_start - duration, window_end, inc=True))
            except Exception:
                starts = [start]
        else:
            starts = [start]

        excluded = {d.replace(microsecond=0) for d in e.get("exdates", [])}

        for s in starts:
            if s.replace(microsecond=0) in excluded:
                continue
            if s + duration < window_start or s > window_end:
                continue
            local = s.astimezone()
            out.append({
                "summary": e.get("summary", "(no title)"),
                "location": e.get("location", ""),
                "allDay": bool(e.get("all_day")),
                "start": local.isoformat(),
                "epoch": int(local.timestamp()),
                "day": local.date().isoformat(),
                "time": "" if e.get("all_day") else clock_format(local, twelve),
            })

    out.sort(key=lambda x: x["epoch"])
    return out


def main() -> int:
    days = 7
    if len(sys.argv) > 1:
        try:
            days = max(1, min(60, int(sys.argv[1])))
        except ValueError:
            pass

    twelve = len(sys.argv) > 2 and sys.argv[2] == "12h"

    if not CONFIG.exists():
        print(json.dumps({"configured": False, "events": [], "calendars": []}))
        return 0

    try:
        feeds = json.loads(CONFIG.read_text())
    except Exception:
        print(json.dumps({"configured": False, "error": "calendars.json is not valid JSON",
                          "events": [], "calendars": []}))
        return 0

    now = datetime.now(timezone.utc)
    window_start = now - timedelta(hours=12)
    window_end = now + timedelta(days=days)

    events: list[dict] = []
    names: list[str] = []
    errors: list[str] = []

    for feed in feeds if isinstance(feeds, list) else []:
        name = str(feed.get("name", "calendar"))
        url = feed.get("url", "")
        if not url:
            continue
        names.append(name)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "gelo-shell"})
            with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
                body = r.read().decode("utf-8", "replace")
        except Exception as exc:
            # Never echo the URL — it is a bearer secret.
            errors.append(f"{name}: {type(exc).__name__}")
            continue

        for ev in expand(parse_events(body), window_start, window_end, twelve):
            ev["calendar"] = name
            events.append(ev)

    events.sort(key=lambda x: x["epoch"])
    print(json.dumps({
        "configured": True,
        "calendars": names,
        "errors": errors,
        "recurrence": _rrule is not None,
        "events": events[:40],
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
