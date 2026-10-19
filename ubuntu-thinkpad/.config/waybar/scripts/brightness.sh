#!/bin/bash
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
queue="$state_dir/brightness.queue"

# Waybar starts one run per scroll event without waiting. Each run queues its event with its
# arrival time, and the run that gets the worker lock applies the whole queue as one batch.
# Otherwise a fast burst leaves a backlog of slow runs that keep stepping after the fingers lift.
ts=${EPOCHREALTIME/./}
ts=$((ts / 1000))

case "$1" in
    wake) ;;
    up | down)
        case "$2" in '' | *[!0-9]*) exit 1 ;; esac
        ;;
    *) exit 1 ;;
esac

mkdir -p "$state_dir"
exec 9>"$state_dir/brightness.queue.lock"
flock 9
printf '%s %s %s %s\n' "$1" "${2:-0}" "${3:--}" "$ts" >> "$queue"
exec 9>&-

exec 8>"$state_dir/brightness.worker.lock"
flock -n 8 || exit 0

process_batch() {
    local info cur max init p power="" cmd step mode ev_ts gap last_ts
    info=$(brightnessctl -m info) || return 1
    IFS=, read -r _dev _class cur _pct max <<<"$info"
    init=$(((cur * 100 + max / 2) / max))
    p=$init
    last_ts=$(cat "$state" 2>/dev/null)
    last_ts=${last_ts:-0}
    while read -r cmd step mode ev_ts; do
        case "$cmd" in
            wake)
                power=on
                if [ "$p" -lt "$floor" ]; then p=$floor; fi
                ;;
            up)
                power=on
                p=$((p + step))
                if [ "$p" -gt 100 ]; then p=100; fi
                ;;
            down)
                if [ "$mode" = scroll ]; then
                    gap=$((ev_ts - last_ts))
                    last_ts=$ev_ts
                    if [ "$gap" -lt "$gap_ms" ]; then
                        # Still the same scroll gesture: never go below FLOOR and never blank.
                        if [ "$p" -gt "$floor" ]; then
                            p=$((p - step))
                            if [ "$p" -lt "$floor" ]; then p=$floor; fi
                        fi
                    elif [ "$p" -le "$floor" ]; then
                        p=0
                    else
                        p=$((p - step))
                        if [ "$p" -lt "$floor" ]; then p=$floor; fi
                    fi
                elif [ "$mode" = off ] && [ "$p" -le "$floor" ]; then
                    p=0
                    power=off
                else
                    p=$((p - step))
                    if [ "$p" -lt "$floor" ]; then p=$floor; fi
                fi
                ;;
        esac
    done <<<"$1"
    echo "$last_ts" > "$state"
    if [ "$power" = on ]; then swaymsg "output * power on" >/dev/null 2>&1; fi
    if [ "$p" -ne "$init" ]; then brightnessctl set "${p}%" >/dev/null; fi
    if [ "$power" = off ]; then swaymsg "output * power off" >/dev/null 2>&1; fi
    return 0
}

while :; do
    exec 9>"$state_dir/brightness.queue.lock"
    flock 9
    if [ ! -s "$queue" ]; then
        exec 8>&-
        exit 0
    fi
    batch=$(cat "$queue")
    : > "$queue"
    exec 9>&-
    process_batch "$batch"
done
