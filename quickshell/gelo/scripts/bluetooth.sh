#!/usr/bin/env bash
#
# bluetooth.sh status      -> {"present":bool,"powered":bool,"connected":N,"name":"..."}
# bluetooth.sh disconnect  -> disconnects every currently connected device
#
# Driven by bluetoothctl rather than Quickshell's Bluetooth service. That
# service reports a null adapter and zero devices on this machine even while
# bluetoothctl sees a controller and two paired devices, so a control bound to
# it would either never appear or never update.

set -uo pipefail

none='{"present":false,"powered":false,"connected":0,"name":""}'

case "${1:-status}" in
status)
    command -v bluetoothctl >/dev/null 2>&1 || { echo "$none"; exit 0; }

    show=$(bluetoothctl show 2>/dev/null) || show=""
    # No 'Powered:' line means no controller — the module hides itself rather
    # than showing a dead icon.
    grep -q 'Powered:' <<<"$show" || { echo "$none"; exit 0; }

    powered=false
    grep -q 'Powered: yes' <<<"$show" && powered=true

    devices=$(bluetoothctl devices Connected 2>/dev/null) || devices=""
    count=0
    name=""
    if [[ -n "$devices" ]]; then
        count=$(grep -c '^Device ' <<<"$devices")
        # Name of the first connected device — "Device AA:BB:.. My Headphones".
        name=$(head -1 <<<"$devices" | cut -d' ' -f3-)
    fi

    jq -n \
        --argjson powered "$powered" \
        --argjson connected "${count:-0}" \
        --arg name "$name" \
        '{present:true, powered:$powered, connected:$connected, name:$name}'
    ;;

disconnect)
    bluetoothctl devices Connected 2>/dev/null | while read -r _ mac _; do
        [[ -n "$mac" ]] && bluetoothctl disconnect "$mac" >/dev/null 2>&1
    done
    ;;
esac
