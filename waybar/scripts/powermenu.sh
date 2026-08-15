#!/bin/bash

choice=$(printf "Sleep\nLog out\nPower off" | wofi --dmenu -i -p "Power")

case "$choice" in
  Sleep)
    systemctl suspend
    ;;
  "Log out")
    hyprctl dispatch exit
    ;;
  "Power off")
    systemctl poweroff
    ;;
esac
