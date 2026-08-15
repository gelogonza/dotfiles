#!/usr/bin/env bash
#
# Compile GLSL sources to Qt's .qsb bundle format.
#
# Qt 6 does not accept raw GLSL at runtime: ShaderEffect wants a pre-baked .qsb
# containing the shader compiled for whichever backend is live (Vulkan, GL,
# Metal...). qsb ships in qt6-shadertools.
#
# The .qsb outputs are checked in so a fresh clone — or the SDDM greeter running
# before any user session exists — does not need the compiler present.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QSB="${QSB:-/usr/lib/qt6/bin/qsb}"

if [[ ! -x "$QSB" ]]; then
    if command -v qsb >/dev/null 2>&1; then
        QSB="$(command -v qsb)"
    else
        echo "error: qsb not found (install qt6-shadertools)" >&2
        exit 1
    fi
fi

shopt -s nullglob
count=0

for src in \
    "$ROOT"/sddm/themes/gelo-liquid/Shaders/*.frag \
    "$ROOT"/quickshell/gelo/Shaders/*.frag
do
    out="$src.qsb"
    "$QSB" --qt6 -o "$out" "$src"
    echo "baked $(basename "$src") -> $(basename "$out")"
    count=$((count + 1))
done

echo "$count shader(s) compiled"
