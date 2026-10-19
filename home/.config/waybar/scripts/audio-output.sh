#!/usr/bin/env bash

set -euo pipefail

sink_name=$(pactl get-default-sink)
sink_info=$(pactl list sinks)
sink_block=$(awk -v sink="$sink_name" '
  /^Sink #[0-9]+/ {
    if (found) exit
    found = 0
  }
  $1 == "Name:" && $2 == sink { found = 1 }
  found { print }
' <<< "$sink_info")

description=$(awk -F': ' '/^[[:space:]]*Description:/ { print $2; exit }' <<< "$sink_block")
active_port=$(awk -F': ' '/^[[:space:]]*Active Port:/ { print $2; exit }' <<< "$sink_block")
case "${active_port,,} ${description,,}" in
  *headphone*|*headset*|*earphone*|*jabra*|*evolve*) device_icon="🎧" ;;
  *hdmi*) device_icon="📺" ;;
  *phone*) device_icon="📞" ;;
  *portable*) device_icon="📱" ;;
  *car*) device_icon="🚗" ;;
  *) device_icon="" ;;
esac

escape_json() {
  sed 's/\\/\\\\/g; s/"/\\"/g'
}

text="$device_icon"
tooltip="Audio Output Device (PipeWire Sink):\n•Target Device: ${description}\n•Active Port: ${active_port}"
printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
  "$(printf '%s' "$text" | escape_json)" \
  "$(printf '%s' "$tooltip" | escape_json)" \
  "normal"
