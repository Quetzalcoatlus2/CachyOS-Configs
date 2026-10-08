#!/bin/sh
# Waybar apt updates module: counts pending upgrades without root (apt-get -s simulates the upgrade).
export LC_ALL=C
n=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')
[ -n "$n" ] || n=0
tip="System Package Synchronization:\\n•Available Updates: $n packages pending\\n•Frequency: Checked hourly\\n\\nAction: Click to run sudo apt update and sudo apt upgrade."
if [ "$n" -gt 0 ]; then
    printf '{"text": "📦%s", "class": "pending", "tooltip": "%s"}\n' "$n" "$tip"
else
    printf '{"text": "📦%s", "class": "updated", "tooltip": "%s"}\n' "$n" "$tip"
fi
