#!/bin/sh
# Changes the backlight by STEP percent. A down press stops at FLOOR (1%).
# Usage: brightness.sh up STEP | down STEP [off|scroll] | wake
#   off    (keys, swipes): a further down press drops to 0% and powers the outputs off.
#   scroll (waybar): one continuous scroll stops at FLOOR; a new scroll after a pause
#          drops to 0% and leaves the outputs on.
# "wake" powers the outputs on (swayidle resume) and lifts a 0% level back to FLOOR.
floor=1
gap_ms=1000
state_dir=${XDG_RUNTIME_DIR:-$HOME/.cache}
state="$state_dir/brightness-scroll.ms"

# Waybar starts one run per scroll event without waiting, so overlapping runs read the same
# level and lose steps. The timestamp is taken on arrival and the read-modify-write is serialised.
now=$(date +%s%3N)
mkdir -p "$state_dir"
exec 9>"$state_dir/brightness.lock"
flock 9

info=$(brightnessctl -m info) || exit 1
IFS=, read -r _dev _class cur _pct max <<EOF
$info
EOF
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
elif [ "$3" = scroll ]; then
    last=$(cat "$state" 2>/dev/null || echo 0)
    echo "$now" > "$state"
    if [ $((now - last)) -lt "$gap_ms" ]; then
        # Still the same scroll gesture: never go below FLOOR and never blank.
        [ "$pct" -le "$floor" ] && exit 0
        new=$((pct - step))
        [ "$new" -lt "$floor" ] && new=$floor
    elif [ "$pct" -le "$floor" ]; then
        new=0
    else
        new=$((pct - step))
        [ "$new" -lt "$floor" ] && new=$floor
    fi
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
