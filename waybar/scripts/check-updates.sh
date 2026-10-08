#!/usr/bin/env bash
count=$(checkupdates 2>/dev/null | wc -l)

if [ "$count" -eq 0 ]; then
    echo '{"text":"0","tooltip":"System is fully up to date","class":"synced"}'
    exit 0
fi

if [ "$count" -le 10 ]; then
    tier="low"
elif [ "$count" -le 35 ]; then
    tier="medium"
else
    tier="high"
fi

echo "{\"text\":\"$count\",\"tooltip\":\"$count packages pending synchronization. Click to execute paru upgrade.\",\"class\":\"$tier\"}"
