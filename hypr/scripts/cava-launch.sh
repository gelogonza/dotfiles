#!/usr/bin/env bash
# Run cava against whatever is actually playing.
#
# cava's `source` is static, and a monitor source only carries audio played to
# THAT sink — so any fixed choice is wrong half the time on a desk that moves
# between USB speakers and Bluetooth headphones. `source = auto` follows the
# *default* sink, which is not the same thing: an application pinned to a
# non-default sink (pipewire remembers per-app routing) leaves cava listening
# to a device with nothing on it, drawing an empty window.
#
# So resolve the sink at launch instead of naming one:
#
#   1. the sink of a stream that is actually playing (not paused)
#   2. failing that, any sink in the RUNNING state
#   3. failing that, the default sink
#
# Speakers, XM4s, HDMI — whatever is playing when cava starts is what it draws.
#
# Usage: cava-launch.sh [extra cava args...]

set -uo pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}/cava/config"
[ -f "$config" ] || config="$HOME/dotfiles/cava/config"

sink=""

# 1. A stream that is playing right now. `Corked: no` means not paused.
sink=$(pactl list sink-inputs 2>/dev/null | awk '
    /^Sink Input #/      { s=""; corked="" }
    /^[[:space:]]*Sink: /  { s=$2 }
    /^[[:space:]]*Corked: /{ corked=$2; if (corked=="no" && s!="") { print s; exit } }
')

# 2. Nothing playing — any sink the server still considers RUNNING.
if [ -z "$sink" ]; then
    sink=$(pactl list short sinks 2>/dev/null | awk '$NF=="RUNNING" { print $1; exit }')
fi

# 3. Give up and follow the default, which is what cava would have done anyway.
if [ -n "$sink" ]; then
    name=$(pactl list short sinks 2>/dev/null | awk -v i="$sink" '$1==i { print $2; exit }')
else
    name=$(pactl get-default-sink 2>/dev/null)
fi

if [ -z "${name:-}" ]; then
    exec cava -p "$config" "$@"          # no PulseAudio answer; let cava try
fi

monitor="${name}.monitor"

# A temp config rather than editing the real one: the real one is generated
# from design/tokens.json and `build-tokens.py --check` fails on staleness, so
# writing a device name into it would break the build every time you changed
# headphones.
tmp=$(mktemp --suffix=.cava)
trap 'rm -f "$tmp"' EXIT
sed "s|^[[:space:]]*source[[:space:]]*=.*|source = ${monitor}|" "$config" > "$tmp"

exec cava -p "$tmp" "$@"
