#!/bin/sh
# Clear wpa_supplicant background scanning after a Wi-Fi association.
#
# NetworkManager configures bgscan (simple:30:-70:86400 on 5 GHz). On a weak
# link that means a scan every 30 s, and each scan takes the radio off-channel
# for seconds. That is enough to underrun video/QUIC buffers and cause rewinds.
# Clearing bgscan stops the periodic scan; scans still happen while disconnected
# or when NetworkManager explicitly requests one.
#
# set_network takes effect on reassociation, so reconnect once. If bgscan is
# already clear, do nothing to avoid a reconnect loop.

[ "$2" = "up" ] || exit 0

dev="$1"
[ -n "$dev" ] || exit 0

# /sys/class/net/<dev>/wireless exists only on Wi-Fi interfaces.
[ -d "/sys/class/net/$dev/wireless" ] || exit 0

WPA_CLI=/usr/sbin/wpa_cli
if [ ! -x "$WPA_CLI" ]; then
    WPA_CLI=$(command -v wpa_cli 2>/dev/null) || exit 0
fi
[ -x "$WPA_CLI" ] || exit 0

id=$("$WPA_CLI" -i "$dev" status 2>/dev/null | sed -n 's/^id=//p')
[ -n "$id" ] || exit 0

current=$("$WPA_CLI" -i "$dev" get_network "$id" bgscan 2>/dev/null | tr -d '"')
if [ -z "$current" ]; then
    exit 0
fi

"$WPA_CLI" -i "$dev" set_network "$id" bgscan "" >/dev/null 2>&1 || exit 0
"$WPA_CLI" -i "$dev" reassociate >/dev/null 2>&1
exit 0
