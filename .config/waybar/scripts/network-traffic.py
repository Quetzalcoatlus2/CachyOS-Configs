#!/usr/bin/env python3
import json
import os
import subprocess
import time

STATE_FILE = "/dev/shm/waybar_net_state"

def get_default_interface():
    try:
        with open("/proc/net/route", "r") as f:
            for line in f.readlines()[1:]:
                fields = line.strip().split()
                if fields[1] == "00000000" and int(fields[3], 16) & 2:
                    return fields[0]
    except Exception:
        pass
    return None

def format_rate(bytes_per_sec):
    if bytes_per_sec < 1024:
        return f"{int(bytes_per_sec)}B"
    elif bytes_per_sec < 1024 * 1024:
        return f"{bytes_per_sec / 1024:.1f}KB"
    elif bytes_per_sec < 1024 * 1024 * 1024:
        return f"{bytes_per_sec / (1024 * 1024):.1f}MB"
    return f"{bytes_per_sec / (1024 * 1024 * 1024):.1f}GB"

iface = get_default_interface()
now = time.time()

if not iface:
    print(json.dumps({"text": "🚫 Disconnected", "class": "disconnected"}))
    exit(0)

rx_path = f"/sys/class/net/{iface}/statistics/rx_bytes"
tx_path = f"/sys/class/net/{iface}/statistics/tx_bytes"

try:
    with open(rx_path, "r") as f:
        rx_bytes = int(f.read().strip())
    with open(tx_path, "r") as f:
        tx_bytes = int(f.read().strip())
except Exception:
    print(json.dumps({"text": "🚫 Disconnected", "class": "disconnected"}))
    exit(0)

down_rate = 0.0
up_rate = 0.0

if os.path.exists(STATE_FILE):
    try:
        with open(STATE_FILE, "r") as f:
            prev_iface, prev_time, prev_rx, prev_tx = f.read().split()
            dt = now - float(prev_time)
            if prev_iface == iface and dt > 0:
                down_rate = max(0.0, (rx_bytes - int(prev_rx)) / dt)
                up_rate = max(0.0, (tx_bytes - int(prev_tx)) / dt)
    except Exception:
        pass

with open(STATE_FILE, "w") as f:
    f.write(f"{iface} {now} {rx_bytes} {tx_bytes}")

is_wifi = os.path.exists(f"/sys/class/net/{iface}/wireless")
down_str = format_rate(down_rate)
up_str = format_rate(up_rate)

if is_wifi:
    ssid = "Wi-Fi"
    signal = 0
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "active,ssid,signal", "dev", "wifi"],
            text=True
        )
        for line in out.strip().splitlines():
            if line.startswith("yes:"):
                parts = line.split(":")
                ssid = parts[1] if len(parts) > 1 else ssid
                signal = int(parts[2]) if len(parts) > 2 else 0
                break
    except Exception:
        pass
    text = f"📶{ssid}({signal}%)🔻{down_str}🔺{up_str}"
else:
    ip_addr = ""
    try:
        out = subprocess.check_output(["ip", "-4", "-brief", "addr", "show", iface], text=True)
        ip_addr = out.split()[2]
    except Exception:
        pass
    text = f"🌐{ip_addr}🔻{down_str}🔺{up_str}"

payload = {
    "text": text,
    "tooltip": f"Interface: {iface}\nDownload: {down_str}/s\nUpload: {up_str}/s",
    "class": "network-traffic"
}

print(json.dumps(payload))
