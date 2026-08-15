#!/usr/bin/env bash
# Screenshot: region / window / full, to the clipboard AND a file, with a
# notification that shows what was captured and offers what to do next.
#
# The previous binding was `grim -g "$(slurp)" ~/Pictures/shot-$(date +%s).png`.
# Three problems, all of which this exists to fix:
#
#   * nothing reached the clipboard, which is where a screenshot usually needs
#     to go;
#   * there was no feedback at all, so a mis-drag that captured nothing looked
#     exactly like success;
#   * `shot-1755262380.png` is not a name you can find again.
#
# Usage: screenshot.sh [region|window|full]

set -uo pipefail

mode="${1:-region}"
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

mkdir -p "$dir"

die() {
    notify-send -a Screenshot -u critical "Screenshot failed" "$1"
    exit 1
}

# Pick the geometry ----------------------------------------------------------
geom=""
case "$mode" in
region)
    # -d draws the selection box while dragging; without it you are guessing.
    geom=$(slurp -d) || exit 0        # empty = cancelled, which is not a failure
    ;;
window)
    # Feed slurp the visible windows so the selection snaps to them, rather
    # than making you trace a window edge by hand. Falls back to the focused
    # window if the compositor gives us nothing to snap to.
    boxes=$(hyprctl -j clients 2>/dev/null | jq -r '
        .[] | select(.hidden == false and .mapped == true)
            | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null)
    if [ -n "$boxes" ]; then
        geom=$(printf '%s\n' "$boxes" | slurp -r) || exit 0
    else
        geom=$(hyprctl -j activewindow 2>/dev/null | jq -r '
            "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null)
        [ -n "$geom" ] && [ "$geom" != "null" ] || die "No focused window."
    fi
    ;;
full)
    : # no geometry: grim captures every output
    ;;
*)
    die "Unknown mode '$mode'. Use region, window or full."
    ;;
esac

# Capture --------------------------------------------------------------------
if [ -n "$geom" ]; then
    grim -g "$geom" "$file" || die "grim could not capture that area."
else
    grim "$file" || die "grim could not capture the screen."
fi

# A zero-byte or missing file is the failure the old binding hid.
[ -s "$file" ] || die "Captured nothing."

wl-copy --type image/png < "$file" || notify-send -a Screenshot \
    "Saved, but not copied" "wl-copy failed — the file is still at $file"

# Report ---------------------------------------------------------------------
# `image-path` is what populates Notification.image, and the card renders it as
# a thumbnail: the point is to show WHAT was captured, not just that something
# was. `-i` alone sets appIcon, which is a different hint and is not drawn.
size=$(du -h "$file" | cut -f1)
dims=$(identify -format '%wx%h' "$file" 2>/dev/null || echo "")
detail="${dims:+$dims · }$size · copied"

actions=(-A "open=Open" -A "folder=Folder")
# Annotation is opt-in on having a tool for it. swappy is the usual choice;
# `sudo pacman -S swappy` and this button appears by itself.
annotator=""
for candidate in swappy satty; do
    if command -v "$candidate" >/dev/null 2>&1; then
        annotator="$candidate"
        actions+=(-A "annotate=Annotate")
        break
    fi
done

# The summary is the filename, not "Screenshot" again — the app name already
# says that, and the one thing you cannot recover from the thumbnail is where
# the file went.
chosen=$(notify-send -a Screenshot \
    --hint="string:image-path:$file" \
    -A "copy=Copy again" "${actions[@]}" \
    "$(basename "$file")" "$detail")

case "$chosen" in
copy)     wl-copy --type image/png < "$file" ;;
open)     xdg-open "$file" >/dev/null 2>&1 & ;;
folder)   xdg-open "$dir" >/dev/null 2>&1 & ;;
annotate)
    case "$annotator" in
    swappy) swappy -f "$file" -o "$file" >/dev/null 2>&1 &&
                wl-copy --type image/png < "$file" ;;
    satty)  satty -f "$file" -o "$file" --early-exit >/dev/null 2>&1 &&
                wl-copy --type image/png < "$file" ;;
    esac
    ;;
esac
