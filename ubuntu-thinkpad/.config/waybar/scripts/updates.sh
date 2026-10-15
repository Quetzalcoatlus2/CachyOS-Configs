#!/bin/sh
# Waybar apt updates module: counts pending upgrades without root (apt-get -s simulates the upgrade).
export LC_ALL=C
n=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')
[ -n "$n" ] || n=0
tip="System Package Synchronization:\\n•Available Updates: $n packages pending\\n•Frequency: Checked hourly\\n\\nAction: Click to run sudo apt update and sudo apt upgrade."
if [ "$n" -eq 0 ]; then
    class=updated
elif [ "$n" -le 10 ]; then
    class=low
elif [ "$n" -le 35 ]; then
    class=medium
else
    class=high
fi
printf '{"text": "📦%s", "class": "%s", "tooltip": "%s"}\n' "$n" "$class" "$tip"
