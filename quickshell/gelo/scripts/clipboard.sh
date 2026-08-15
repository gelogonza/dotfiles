#!/usr/bin/env bash
#
# clipboard.sh list          -> [{"id":"123","preview":"...","kind":"text|image"}, ...]
# clipboard.sh copy <id>     -> puts that entry back on the clipboard
# clipboard.sh wipe          -> clears the history
#
# Wraps cliphist. Entries are addressed by ID, never by content: the decoded
# text is piped straight from cliphist into wl-copy and never passes through a
# shell argument, a log line, or this script's stdout. Clipboard history holds
# passwords and tokens often enough that it is worth being careful with.

set -uo pipefail

case "${1:-list}" in
list)
    command -v cliphist >/dev/null 2>&1 || { echo '[]'; exit 0; }

    # cliphist list emits "<id>\t<preview>". The preview is already collapsed to
    # a single line by cliphist, and binary entries come through as
    # "[[ binary data ... ]]".
    cliphist list 2>/dev/null | jq -R -s '
        split("\n")
        | map(select(length > 0))
        | map(
            (split("\t")) as $parts
            | {
                id:      $parts[0],
                preview: ($parts[1:] | join("\t")),
              }
            | .kind = (if (.preview | test("^\\[\\[ ?binary")) then "image" else "text" end)
          )
    ' 2>/dev/null || echo '[]'
    ;;

copy)
    id="${2:-}"
    [[ -z "$id" ]] && exit 0

    # decode reads the entry by id and writes the raw bytes; wl-copy takes them
    # on stdin. Nothing here interpolates the content.
    printf '%s\t' "$id" | cliphist decode 2>/dev/null | wl-copy
    ;;

wipe)
    cliphist wipe 2>/dev/null
    ;;
esac
