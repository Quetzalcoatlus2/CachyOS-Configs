#!/bin/sh
# Changes the backlight by STEP percent and stops at FLOOR so the panel never goes black.
# Usage: brightness.sh up|down STEP [off]
# "off" makes a down press at the floor power the outputs off; only the brightness keys pass it.
floor=1

case "$1" in
    up | down) ;;
    *) exit 1 ;;
esac
step=$2
max=$(brightnessctl max) || exit 1
cur=$(brightnessctl get) || exit 1
pct=$(((cur * 100 + max / 2) / max))

if [ "$1" = up ]; then
    new=$((pct + step))
    [ "$new" -gt 100 ] && new=100
    swaymsg "output * power on" >/dev/null 2>&1
else
    if [ "$3" = off ] && [ "$pct" -le "$floor" ]; then
        swaymsg "output * power off" >/dev/null 2>&1
        exit 0
    fi
    new=$((pct - step))
    [ "$new" -lt "$floor" ] && new=$floor
fi
brightnessctl set "${new}%" >/dev/null
