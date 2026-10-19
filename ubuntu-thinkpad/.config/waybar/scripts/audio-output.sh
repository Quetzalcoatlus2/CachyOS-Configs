#!/bin/sh
# Prints one icon for the active output port of the default sink: headphones, HDMI, or speaker.
sink=$(pactl get-default-sink 2>/dev/null) || exit 0
port=$(pactl list sinks | awk -v s="$sink" '
    /^[[:space:]]*Name: / { cur = ($2 == s) }
    cur && /^[[:space:]]*Active Port: / { sub(/^[^:]*: /, ""); print; exit }')
case "$port" in
    *[Hh]eadphone*|*[Hh]eadset*|*[Hh]ands-free*) printf '%s\n' "🎧" ;;
    *[Hh][Dd][Mm][Ii]*) printf '%s\n' "📺" ;;
    *) printf '%s\n' "🔈" ;;
esac
