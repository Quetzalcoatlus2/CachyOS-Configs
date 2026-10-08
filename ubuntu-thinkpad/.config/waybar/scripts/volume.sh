#!/bin/sh
# Changes the default sink by 5% and clamps it to 0-100%. Usage: volume.sh up|down
cur=$(pactl get-sink-volume @DEFAULT_SINK@ | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /%$/) { sub(/%/, "", $i); print $i; exit } }')
[ -n "$cur" ] || exit 1
case "$1" in
    up) new=$((cur + 5)) ;;
    down) new=$((cur - 5)) ;;
    *) exit 1 ;;
esac
[ "$new" -gt 100 ] && new=100
[ "$new" -lt 0 ] && new=0
pactl set-sink-volume @DEFAULT_SINK@ "${new}%"
