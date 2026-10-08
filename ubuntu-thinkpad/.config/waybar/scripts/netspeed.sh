#!/bin/sh
# Waybar network module: Wi-Fi name, signal, and live throughput in one JSON line per second.
export LC_NUMERIC=C
PATH="$PATH:/usr/sbin:/sbin"

human() { # $1 = bytes, $2 = suffix, $3 = separator before unit (default space)
    sep=${3-' '}
    awk -v b="$1" -v s="$2" -v g="$sep" 'BEGIN {
        if (b >= 1073741824)     printf "%.2f%sGB%s", b / 1073741824, g, s
        else if (b >= 1048576)   printf "%.1f%sMB%s", b / 1048576, g, s
        else if (b >= 1024)      printf "%.1f%sKB%s", b / 1024, g, s
        else                     printf "%d%sB%s", b, g, s
    }'
}

prev_rx=0
prev_tx=0
first=1
tick=0
ssid=""
sig=""
while :; do
    iface=$(ip -o route show default 2>/dev/null | awk '{print $5; exit}')
    if [ -n "$iface" ] && [ -r "/sys/class/net/$iface/statistics/rx_bytes" ]; then
        # Wi-Fi name and signal refresh every 5 s from the cached AP list (no forced rescan).
        if [ $((tick % 5)) -eq 0 ]; then
            wifi=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -F: '$1 == "yes" { print $2 "|" $3; exit }')
            ssid=$(printf '%s' "${wifi%|*}" | tr -d '"\\&<>')
            sig=${wifi##*|}
        fi
        addr=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{print $4; exit}')
        rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes")
        tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes")
        if [ "$first" = 1 ]; then
            drx=0
            dtx=0
            first=0
        else
            drx=$((rx - prev_rx))
            dtx=$((tx - prev_tx))
        fi
        prev_rx=$rx
        prev_tx=$tx
        down=$(human "$drx" "/s")
        up=$(human "$dtx" "/s")
        dbar=$(human "$drx" "" "")
        ubar=$(human "$dtx" "" "")
        if [ -n "$ssid" ]; then
            net="📶$ssid($sig%)"
        else
            net="🌐${addr:-$iface}"
        fi
        sigtxt=${sig:+$sig%}
        text="$net🔻$dbar🔺$ubar"
        tip="Network Connection ($iface):\n•Wi-Fi Name: ${ssid:-none}\n•Signal Quality: ${sigtxt:-n/a}\n•IP Address: ${addr:-none}\n•Download: $down\n•Upload: $up\n•Total Received (since boot): $(human "$rx" "")\n•Total Sent (since boot): $(human "$tx" "")\n\nAction: Click to launch nmtui."
    else
        ssid=""
        sig=""
        text="🚫 offline"
        tip="No default network route.\n\nAction: Click to launch nmtui."
    fi
    printf '{"text": "%s", "tooltip": "%s"}\n' "$text" "$tip"
    tick=$((tick + 1))
    sleep 1
done
