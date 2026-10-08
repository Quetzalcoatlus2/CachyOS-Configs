#!/bin/sh
# Waybar root disk module; percent is used/(used+avail), matching the 93% reading.
set -- $(df -B1 --output=used,avail / | tail -n 1)
pct=$(( $1 * 100 / ($1 + $2) ))
set -- $(df -h --output=used,avail,size / | tail -n 1)
if [ "$pct" -ge 90 ]; then cls=critical; elif [ "$pct" -ge 80 ]; then cls=warning; else cls=normal; fi
printf '{"text": "💾%d%%", "class": "%s", "tooltip": "Root Storage Subvolume:\\n•Mount Point: /\\n•Space Consumed: %s / %s\\n•Available Storage: %s"}\n' "$pct" "$cls" "$1" "$3" "$2"
