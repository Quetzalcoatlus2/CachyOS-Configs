#!/bin/sh
# Changes the default sink by STEP percent (default 5), clamped to 0-100%. Usage: volume.sh up|down [STEP]
cur=$(pactl get-sink-volume @DEFAULT_SINK@ | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /%$/) { sub(/%/, "", $i); print $i; exit } }')
[ -n "$cur" ] || exit 1
step=${2:-5}
case "$step" in '' | *[!0-9]*) exit 1 ;; esac
case "$1" in
    up) new=$((cur + step)) ;;
    down) new=$((cur - step)) ;;
    *) exit 1 ;;
esac
[ "$new" -gt 100 ] && new=100
[ "$new" -lt 0 ] && new=0
pactl set-sink-volume @DEFAULT_SINK@ "${new}%"
