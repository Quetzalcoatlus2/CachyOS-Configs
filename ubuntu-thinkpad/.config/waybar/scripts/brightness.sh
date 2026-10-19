#!/bin/sh
# Changes the backlight by STEP percent. A down press stops at FLOOR (1%); a further
# down press with "off" drops to 0% and powers the outputs off.
# Usage: brightness.sh up|down STEP [off] | wake
# "wake" powers the outputs on (swayidle resume) and lifts a 0% level back to FLOOR.
floor=1

max=$(brightnessctl max) || exit 1
cur=$(brightnessctl get) || exit 1
pct=$(((cur * 100 + max / 2) / max))

case "$1" in
    wake)
        swaymsg "output * power on" >/dev/null 2>&1
        [ "$pct" -lt "$floor" ] && brightnessctl set "${floor}%" >/dev/null
        exit 0
        ;;
    up | down) ;;
    *) exit 1 ;;
esac
step=$2

if [ "$1" = up ]; then
    new=$((pct + step))
    [ "$new" -gt 100 ] && new=100
    swaymsg "output * power on" >/dev/null 2>&1
else
    if [ "$3" = off ] && [ "$pct" -le "$floor" ]; then
        brightnessctl set 0% >/dev/null
        swaymsg "output * power off" >/dev/null 2>&1
        exit 0
    fi
    new=$((pct - step))
    [ "$new" -lt "$floor" ] && new=$floor
fi
brightnessctl set "${new}%" >/dev/null
