#!/bin/bash

# Auto-detect location and get weather with icon (Fahrenheit)
WEATHER=$(curl -sf --max-time 5 "https://wttr.in/Bloomington,IN?format=%c%t&u" 2>/dev/null)

if [ -z "$WEATHER" ]; then
  echo "🌡️ N/A"
else
  # Remove the + sign from positive temperatures
  echo "$WEATHER" | sed 's/+//g'
fi
