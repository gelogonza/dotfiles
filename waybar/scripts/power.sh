#!/bin/bash

chosen=$(printf "⏻ Power Off\n⭮ Reboot\n⏾ Suspend\n⇦ Log Out" | wofi --dmenu --prompt "Power")

case "$chosen" in
  "⏻ Power Off") poweroff ;;
  "⭮ Reboot") reboot ;;
  "⏾ Suspend") systemctl suspend ;;
  "⇦ Log Out") hyprctl dispatch exit ;;
esac
