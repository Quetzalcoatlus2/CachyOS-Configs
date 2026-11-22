#!/usr/bin/env bash
# Cycle through visible windows and show the newly focused window's title.
# Sway's focus next/prev does not reliably cross container boundaries, so this
# builds the list itself and wraps around.
set -euo pipefail

direction=${1:-next}
case "$direction" in
    next|prev) ;;
    *) direction=next ;;
esac

# Include every window on a currently visible workspace, including tabs and
# stacked windows that are not the active one.
visible=$(swaymsg -t get_workspaces | jq -c '[.[] | select(.visible) | .name]')
mapfile -t windows < <(swaymsg -t get_tree | jq -r --argjson visible "$visible" '
    .. | objects
    | select(.type == "workspace" and (.name as $n | $visible | index($n)))
    | .. | objects
    | select(.type == "con" and .pid != null and .name != null)
    | [(.id|tostring),
       (.app_id // .window_properties.class // "Window"),
       (.name | gsub("[\\t\\n]"; " "))]
    | @tsv
')
[ "${#windows[@]}" -gt 0 ] || exit 0

focused=$(swaymsg -t get_tree | jq -r '
    first(.. | objects | select(.type == "con" and .focused == true and .pid != null) | .id)
')

index=-1
for i in "${!windows[@]}"; do
    id=${windows[$i]%%$'\t'*}
    if [ "$id" = "$focused" ]; then
        index=$i
        break
    fi
done

count=${#windows[@]}
if [ "$index" -lt 0 ]; then
    index=0
elif [ "$direction" = next ]; then
    index=$(( (index + 1) % count ))
else
    index=$(( (index - 1 + count) % count ))
fi

target=${windows[$index]%%$'\t'*}
IFS=$'\t' read -r _ app title <<< "${windows[$index]}"
swaymsg "[con_id=$target] focus" >/dev/null 2>&1 || true

# Replace the previous OSD instead of stacking one notification per keypress.
idfile="${XDG_RUNTIME_DIR:-/tmp}/sway-focus-osd-${UID}.id"
replaces=()
if [ -s "$idfile" ]; then
    read -r oldid < "$idfile" || true
    [ -n "${oldid:-}" ] && replaces=(-r "$oldid")
fi
if newid=$(notify-send -a "Window focus" -p "${replaces[@]}" "$app" "$title" 2>/dev/null); then
    printf '%s\n' "$newid" > "$idfile"
fi
