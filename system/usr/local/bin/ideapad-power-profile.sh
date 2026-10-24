#!/bin/sh
# Apply AC/battery power settings for the IdeaPad.
# Called by ideapad-power-profile.service on udev power_supply events and at boot.

set -u

ac_online=""
for supply in /sys/class/power_supply/ADP* /sys/class/power_supply/AC*; do
    if [ -r "$supply/online" ]; then
        ac_online=$(cat "$supply/online")
        break
    fi
done

[ -n "$ac_online" ] || exit 0

if [ "$ac_online" = "1" ]; then
    [ -w /sys/devices/system/cpu/cpufreq/boost ] && echo 1 > /sys/devices/system/cpu/cpufreq/boost
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [ -w "$f" ] && echo auto > "$f" 2>/dev/null
    done
    for p in /sys/bus/pci/devices/*/power/control; do
        [ -w "$p" ] && echo on > "$p" 2>/dev/null
    done
    /usr/bin/powerprofilesctl set balanced 2>/dev/null || true
else
    [ -w /sys/devices/system/cpu/cpufreq/boost ] && echo 0 > /sys/devices/system/cpu/cpufreq/boost
    for f in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [ -w "$f" ] && echo low > "$f" 2>/dev/null
    done
    for p in /sys/bus/pci/devices/*/power/control; do
        [ -w "$p" ] && echo auto > "$p" 2>/dev/null
    done
    /usr/bin/powerprofilesctl set power-saver 2>/dev/null || true
fi
