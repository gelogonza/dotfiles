#!/usr/bin/env bash
#
# weather.sh [location]
#
# Emits {"temp":N,"precip":N,"condition":"..."} or {} on any failure.
#
# With no location argument wttr.in geolocates by IP. See the privacy note in
# Services/Weather.qml — prefer passing an explicit city.
#
# Everything about this is best-effort: a status bar must never block or shout
# because a weather server is down.

set -uo pipefail

loc="${1:-}"

raw=$(curl -fsS --max-time 8 "https://wttr.in/${loc}?format=j1" 2>/dev/null) || { echo '{}'; exit 0; }
[[ -z "$raw" ]] && { echo '{}'; exit 0; }

echo "$raw" | jq -c '
  (.current_condition[0] // {}) as $c
  | if $c == {} then {} else
      {
        temp:      ($c.temp_C | tonumber),
        precip:    (($c.precipMM // "0") | tonumber | round),
        condition: ($c.weatherDesc[0].value // "")
      }
    end' 2>/dev/null || echo '{}'
