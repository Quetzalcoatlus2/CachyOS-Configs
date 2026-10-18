#!/bin/sh
# Apply CAKE to the first wireless interface that comes up.
# Matched by device type rather than a hardcoded name (wlan0/wlp2s0/...),
# so this keeps working across machines and interface renames.
set -e

[ "$2" = "up" ] || exit 0

dev="$1"
[ -n "$dev" ] || exit 0

# /sys/class/net/<dev>/wireless exists only on Wi-Fi interfaces.
[ -d "/sys/class/net/$dev/wireless" ] || exit 0

/usr/bin/tc qdisc replace dev "$dev" root cake
