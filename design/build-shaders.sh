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

# The .frag files this compiles are GENERATED copies of design/shaders/*.frag.
# Running this without regenerating them first silently bakes the previous
# version of the shader, which is extremely confusing to debug — so do it here
# rather than relying on remembering the order.
"$ROOT/design/build-tokens.py" > /dev/null

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
