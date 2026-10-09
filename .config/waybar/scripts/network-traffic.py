#!/usr/bin/env python3
import json
import os
import subprocess
import time

STATE_FILE = "/dev/shm/waybar_net_state"

def format_rate(bytes_per_sec):
    if bytes_per_sec < 1024:
        return f"{int(bytes_per_sec)}B"
    elif bytes_per_sec < 1024 * 1024:
        return f"{bytes_per_sec / 1024:.1f}KB"
    elif bytes_per_sec < 1024 * 1024 * 1024:
        return f"{bytes_per_sec / (1024 * 1024):.1f}MB"
    return f"{bytes_per_sec / (1024 * 1024 * 1024):.1f}GB"

def get_default_route():
    iface, gw = None, None
    try:
        with open("/proc/net/route", "r") as f:
            for line in f.readlines()[1:]:
                fields = line.strip().split()
                if fields[1] == "00000000" and int(fields[3], 16) & 2:
                    iface = fields[0]
                    gw_hex = fields[2]
                    gw = ".".join(str(int(gw_hex[i:i+2], 16)) for i in (6, 4, 2, 0))
                    break
    except Exception:
        pass
    return iface, gw

iface, gw = get_default_route()
now = time.time()

# Fallback: check for any active non-loopback interface if no default route
if not iface:
    try:
        candidates = [d for d in os.listdir("/sys/class/net") if d != "lo"]
        for c in candidates:
            with open(f"/sys/class/net/{c}/operstate", "r") as f:
                if f.read().strip() == "up":
                    iface = c
                    break
    except Exception:
        pass

if not iface:
    payload = {
        "text": "🚫 Disconnected",
        "tooltip": "Network Interface Status:\n•Status: Disconnected",
        "class": "disconnected"
    }
    print(json.dumps(payload))
    exit(0)

# Check IP address and subnet
ip_addr = ""
cidr = ""
try:
    addr_out = subprocess.check_output(["ip", "-4", "-o", "addr", "show", "dev", iface], text=True)
    for line in addr_out.strip().splitlines():
        parts = line.split()
        if len(parts) >= 4 and "/" in parts[3]:
            ip_addr, cidr = parts[3].split("/", 1)
            break
except Exception:
    pass

# Physical link without an assigned IP
if not ip_addr:
    payload = {
        "text": f"🔗 {iface} (No IP)",
        "tooltip": f"Network Interface Status:\n•Device: {iface}\n•Status: Connected (No IP)",
        "class": "linked"
    }
    print(json.dumps(payload))
    exit(0)

# Byte rate calculation
rx_path = f"/sys/class/net/{iface}/statistics/rx_bytes"
tx_path = f"/sys/class/net/{iface}/statistics/tx_bytes"
down_rate = 0.0
up_rate = 0.0

try:
    with open(rx_path, "r") as f:
        rx_bytes = int(f.read().strip())
    with open(tx_path, "r") as f:
        tx_bytes = int(f.read().strip())

    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            prev_iface, prev_time, prev_rx, prev_tx = f.read().split()
            dt = now - float(prev_time)
            if prev_iface == iface and dt > 0:
                down_rate = max(0.0, (rx_bytes - int(prev_rx)) / dt)
                up_rate = max(0.0, (tx_bytes - int(prev_tx)) / dt)
except Exception:
    rx_bytes, tx_bytes = 0, 0

try:
    with open(STATE_FILE, "w") as f:
        f.write(f"{iface} {now} {rx_bytes} {tx_bytes}")
except Exception:
    pass

down_str = format_rate(down_rate)
up_str = format_rate(up_rate)
is_wifi = os.path.exists(f"/sys/class/net/{iface}/wireless")

if is_wifi:
    ssid = "Wi-Fi"
    signal = 0
    try:
        wifi_out = subprocess.check_output(
            ["nmcli", "-t", "-f", "active,ssid,signal", "dev", "wifi"],
            text=True
        )
        for line in wifi_out.strip().splitlines():
            if line.startswith("yes:"):
                parts = line.split(":")
                ssid = parts[1] if len(parts) > 1 else ssid
                signal = int(parts[2]) if len(parts) > 2 else 0
                break
    except Exception:
        pass
    text = f"📶{ssid}({signal}%)🔻{down_str}🔺{up_str}"
else:
    text = f"🌐{ip_addr}/{cidr}🔻{down_str}🔺{up_str}"

tooltip_lines = [
    "Network Interface Status:",
    f"•Device: {iface}",
    f"•IP Address: {ip_addr}/{cidr}"
]
if gw:
    tooltip_lines.append(f"•Gateway: {gw}")
tooltip_lines.append(f"•Download: {down_str}")
tooltip_lines.append(f"•Upload: {up_str}")

payload = {
    "text": text,
    "tooltip": "\n".join(tooltip_lines),
    "class": "network-traffic"
}

print(json.dumps(payload))
