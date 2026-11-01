#!/usr/bin/env bash

STATE_FILE="/dev/shm/waybar_net_state"
META_FILE="/dev/shm/waybar_net_meta"

format_rate() {
    local bps=$1
    if (( bps < 1024 )); then
        printf "%dB" "$bps"
    elif (( bps < 1048576 )); then
        local kb=$(( bps * 10 / 1024 ))
        printf "%d.%dKB" $(( kb / 10 )) $(( kb % 10 ))
    elif (( bps < 1073741824 )); then
        local mb=$(( bps * 10 / 1048576 ))
        printf "%d.%dMB" $(( mb / 10 )) $(( mb % 10 ))
    else
        local gb=$(( bps * 10 / 1073741824 ))
        printf "%d.%dGB" $(( gb / 10 )) $(( gb % 10 ))
    fi
}

iface=""
gw=""
while read -r r_iface r_dest r_gw r_flags _; do
    if [[ "$r_dest" == "00000000" ]] && (( (16#$r_flags & 2) != 0 )); then
        iface="$r_iface"
        gw="$(( 16#${r_gw:6:2} )).$(( 16#${r_gw:4:2} )).$(( 16#${r_gw:2:2} )).$(( 16#${r_gw:0:2} ))"
        break
    fi
done < /proc/net/route

if [[ -z "$iface" ]]; then
    for devpath in /sys/class/net/*; do
        dev="${devpath##*/}"
        [[ "$dev" == "lo" ]] && continue
        read -r state < "$devpath/operstate" 2>/dev/null
        if [[ "$state" == "up" ]]; then
            iface="$dev"
            break
        fi
    done
fi

if [[ -z "$iface" ]]; then
    printf '{"text":"🚫 Disconnected","tooltip":"Network Interface Status:\\n•Status: Disconnected","class":"disconnected"}\n'
    exit 0
fi

read -r up_str _ < /proc/uptime
now_cs="${up_str/./}"
now_sec="${up_str%.*}"

ip_addr=""
cidr=""
ssid="Wi-Fi"
if [[ -f "$META_FILE" ]]; then
    IFS='|' read -r m_iface m_time m_ip m_cidr m_ssid < "$META_FILE"
    if [[ "$m_iface" == "$iface" ]] && (( now_sec - m_time < 15 )) && [[ -n "$m_ip" ]]; then
        ip_addr="$m_ip"
        cidr="$m_cidr"
        ssid="$m_ssid"
    fi
fi

if [[ -z "$ip_addr" ]]; then
    while read -r _ _ _ addr_cidr _; do
        if [[ "$addr_cidr" == */* ]]; then
            ip_addr="${addr_cidr%/*}"
            cidr="${addr_cidr#*/}"
            break
        fi
    done < <(ip -4 -o addr show dev "$iface" 2>/dev/null)

    if [[ -d "/sys/class/net/$iface/wireless" ]]; then
        ssid_out=$(nmcli -g GENERAL.CONNECTION dev show "$iface" 2>/dev/null)
        [[ -n "$ssid_out" ]] && ssid="$ssid_out"
    fi
    printf "%s|%s|%s|%s|%s\n" "$iface" "$now_sec" "$ip_addr" "$cidr" "$ssid" > "$META_FILE"
fi

if [[ -z "$ip_addr" ]]; then
    printf '{"text":"🔗 %s (No IP)","tooltip":"Network Interface Status:\\n•Device: %s\\n•Status: Connected (No IP)","class":"linked"}\n' "$iface" "$iface"
    exit 0
fi

read -r rx_bytes < "/sys/class/net/$iface/statistics/rx_bytes"
read -r tx_bytes < "/sys/class/net/$iface/statistics/tx_bytes"
down_rate=0
up_rate=0

if [[ -f "$STATE_FILE" ]]; then
    read -r p_iface p_cs p_rx p_tx < "$STATE_FILE"
    p_cs="${p_cs//./}"; dt_cs=$(( now_cs - p_cs ))
    if [[ "$p_iface" == "$iface" ]] && (( dt_cs > 0 )); then
        (( rx_bytes >= p_rx )) && down_rate=$(( (rx_bytes - p_rx) * 100 / dt_cs ))
        (( tx_bytes >= p_tx )) && up_rate=$(( (tx_bytes - p_tx) * 100 / dt_cs ))
    fi
fi
printf "%s %s %s %s\n" "$iface" "$now_cs" "$rx_bytes" "$tx_bytes" > "$STATE_FILE"

down_str=$(format_rate "$down_rate")
up_str=$(format_rate "$up_rate")

if [[ -d "/sys/class/net/$iface/wireless" ]]; then
    signal=0
    while read -r w_iface _ w_link _; do
        if [[ "${w_iface%:}" == "$iface" ]]; then
            link_int="${w_link%.*}"
            signal=$(( link_int * 100 / 70 ))
            (( signal > 100 )) && signal=100
            break
        fi
    done < /proc/net/wireless
    text="📶${ssid}(${signal}%)🔻${down_str}🔺${up_str}"
else
    text="🌐${ip_addr}/${cidr}🔻${down_str}🔺${up_str}"
fi

tooltip="Network Interface Status:\\n•Device: ${iface}\\n•IP Address: ${ip_addr}/${cidr}"
[[ -n "$gw" ]] && tooltip="${tooltip}\\n•Gateway: ${gw}"
tooltip="${tooltip}\\n•Download: ${down_str}\\n•Upload: ${up_str}"

printf '{"text":"%s","tooltip":"%s","class":"network-traffic"}\n' "$text" "$tooltip"
