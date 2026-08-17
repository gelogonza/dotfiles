#!/usr/bin/env bash
#
# weather.sh [location] [imperial|metric]
#
# Emits {"temp":N,"precip":N,"condition":"..."} or {} on any failure.
# `precip` is inches under imperial and millimetres under metric — the caller
# knows which it asked for, so the unit is not repeated in the payload.
#
# With no location argument wttr.in geolocates by IP. See the privacy note in
# Services/Weather.qml — prefer passing an explicit city.
#
# Everything about this is best-effort: a status bar must never block or shout
# because a weather server is down.

set -uo pipefail

loc="${1:-}"
units="${2:-metric}"

raw=$(curl -fsS --max-time 8 "https://wttr.in/${loc}?format=j1" 2>/dev/null) || { echo '{}'; exit 0; }
[[ -z "$raw" ]] && { echo '{}'; exit 0; }

# wttr's j1 payload carries both scales, so the unit is a field choice rather
# than a conversion — no rounding error, and no drift if wttr changes its
# rounding. Precipitation is only published in mm, so that one is converted.
echo "$raw" | jq -c --arg units "$units" '
  (.current_condition[0] // {}) as $c
  | if $c == {} then {} else
      (($c.precipMM // "0") | tonumber) as $mm
      | {
          temp:      (if $units == "imperial" then ($c.temp_F | tonumber)
                                              else ($c.temp_C | tonumber) end),
          precip:    (if $units == "imperial" then (($mm / 25.4) * 100 | round / 100)
                                              else ($mm | round) end),
          condition: ($c.weatherDesc[0].value // "")
        }
    end' 2>/dev/null || echo '{}'
