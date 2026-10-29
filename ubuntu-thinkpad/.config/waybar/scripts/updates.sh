#!/usr/bin/env bash
# Simulate upgrades using the local APT indexes; never require root here.
set -u
export LC_ALL=C
rc=0
output=$(apt-get -s --with-new-pkgs upgrade 2>&1) || rc=$?
# Unreadable root-only source lists make the count partial, not unusable.
unreadable_re='^W: Unable to read /etc/apt/sources\.list(\.d/[^ ]*)? - open \(13: Permission denied\)$'
partial=$(printf '%s\n' "$output" | grep -E "$unreadable_re")
if (( rc == 0 )) && printf '%s\n' "$output" | grep -vE "$unreadable_re" | grep -qE '^[WE]:'; then
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
mark=
if [[ -n $partial ]]; then
    mark='?'
    tip="$tip

Partial count: some APT sources are readable by root only:
$partial
Click to run the full sudo update."
fi
if [[ -n $partial ]]; then
    class=partial
elif (( n == 0 )); then
    class=updated
elif (( n <= 10 )); then
    class=low
elif (( n <= 35 )); then
    class=medium
else
    class=high
fi
python3 - "$n$mark" "$class" "$tip" <<'PY'
import html
import json
import sys
print(json.dumps({"text": f"📦{sys.argv[1]}", "class": sys.argv[2], "tooltip": html.escape(sys.argv[3])}))
PY
