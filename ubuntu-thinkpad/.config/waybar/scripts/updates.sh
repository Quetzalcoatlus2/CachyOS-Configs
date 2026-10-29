#!/usr/bin/env bash
# Simulate upgrades using the local APT indexes; never require root here.
set -u
export LC_ALL=C
rc=0
output=$(apt-get -s upgrade 2>&1) || rc=$?
if (( rc == 0 )) && printf '%s\n' "$output" | grep -qE '^[WE]:'; then
    rc=1
fi
if (( rc != 0 )); then
    python3 - "$rc" "$output" <<'PY'
import html
import json
import sys
print(json.dumps({
    "text": "📦!",
    "class": "error",
    "tooltip": html.escape(f"APT update check failed (exit {sys.argv[1]}):\n{sys.argv[2]}"),
}))
PY
    exit 0
fi
n=$(printf '%s\n' "$output" | awk '/^Inst / {n++} END {print n+0}')
tip="System Package Synchronization:
•Available Updates: $n packages pending
•Frequency: Checked hourly using local APT indexes

Action: Click to refresh indexes, review and install Ubuntu updates.
Private source builds, Snap and Flatpak are not updated by this widget."
if (( n == 0 )); then
    class=updated
elif (( n <= 10 )); then
    class=low
elif (( n <= 35 )); then
    class=medium
else
    class=high
fi
python3 - "$n" "$class" "$tip" <<'PY'
import json
import sys
print(json.dumps({"text": f"📦{sys.argv[1]}", "class": sys.argv[2], "tooltip": sys.argv[3]}))
PY
