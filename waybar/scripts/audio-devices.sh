#!/bin/bash

devices=$(wpctl status | grep -E 'Audio/Sink|Audio/Source' -A 20 | grep -E '^[[:space:]]+[0-9]+\.' | sed 's/^[[:space:]]*//')

choice=$(echo "$devices" | wofi --dmenu -i -p "Audio device")

id=$(echo "$choice" | awk '{print $1}' | tr -d '.')

[ -n "$id" ] && wpctl set-default "$id"
