#!/usr/bin/env bash

ARCH=$(checkupdates 2>/dev/null | wc -l)
AUR=$(paru -Qum 2>/dev/null | wc -l)
TOTAL=$(( ARCH + AUR ))

if [ "$TOTAL" -eq 0 ]; then
    CLASS="synced"
elif [ "$TOTAL" -le 10 ]; then
    CLASS="low"
elif [ "$TOTAL" -le 35 ]; then
    CLASS="medium"
else
    CLASS="high"
fi

printf '{"text": "%s", "class": "%s", "tooltip": "System Package Synchronization:\\n• Available Updates: %s pending (%s repo, %s AUR)\\n• Frequency: Checked hourly\\n\\nAction: Click to execute paru upgrade."}\n' \
    "$TOTAL" "$CLASS" "$TOTAL" "$ARCH" "$AUR"
