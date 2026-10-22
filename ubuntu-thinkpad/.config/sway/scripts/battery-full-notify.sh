#!/bin/sh
# Notify once per charge cycle when the battery reaches 100%.
# Skipped while docked to the DisplayLink (evdi) monitor, which keeps the
# laptop charging all the time and would otherwise nag all day.

BAT=/sys/class/power_supply/BAT0
RUNDIR=${XDG_RUNTIME_DIR:-/tmp}
STATE="$RUNDIR/battery-full-notified"

# Single instance: sway exec runs again on every reload.
exec 9>"$RUNDIR/battery-full-notify.lock"
flock -n 9 || exit 0

docked() {
    for s in /sys/class/drm/card*-*/status; do
        c=${s%/status}
        [ "$(cat "$s" 2>/dev/null)" = connected ] || continue
        case $(readlink -f "$c/device/driver" 2>/dev/null) in
            *evdi*) return 0 ;;
        esac
    done
    return 1
}

while :; do
    status=$(cat "$BAT/status" 2>/dev/null)
    cap=$(cat "$BAT/capacity" 2>/dev/null)
    if [ "$status" = Full ] || { [ "$status" = Charging ] && [ "${cap:-0}" -ge 100 ]; }; then
        if [ ! -e "$STATE" ]; then
            : > "$STATE"
            docked || notify-send -a batsignal -t 15000 -i battery-full-charged \
                "Battery full" "Battery is fully charged"
        fi
    else
        rm -f "$STATE"
    fi
    sleep 60
done
