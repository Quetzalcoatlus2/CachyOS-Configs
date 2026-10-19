#!/bin/sh
# Prints an icon for headphones or HDMI on the default sink; prints nothing for the built-in speaker.
sink=$(pactl get-default-sink 2>/dev/null) || exit 0
port=$(pactl list sinks | awk -v s="$sink" '
    /^[[:space:]]*Name: / { cur = ($2 == s) }
    cur && /^[[:space:]]*Active Port: / { sub(/^[^:]*: /, ""); print; exit }')
case "$port" in
    *[Hh]eadphone*|*[Hh]eadset*|*[Hh]ands-free*) printf '%s\n' "🎧" ;;
    *[Hh][Dd][Mm][Ii]*) printf '%s\n' "📺" ;;
    *[Ss]peaker*) ;;
    *) printf '%s\n' "🔈" ;;
esac
