#!/bin/sh
# Move the focused container to the next or previous numbered workspace
# without wrapping. Creates the target workspace when needed.
set -eu

case "${1:-}" in
    next) step=1 ;;
    prev) step=-1 ;;
    *) printf 'Usage: %s next|prev\n' "${0##*/}" >&2; exit 2 ;;
esac

# Held key repeats can overlap; serialize them and drop the extra presses.
lock="${XDG_RUNTIME_DIR:-/tmp}/sway-move-container-workspace.lock"
exec 9>"$lock"
flock -n 9 || exit 0

current=$(swaymsg -t get_workspaces -r |
    jq -r '.[] | select(.focused) | .num' |
    head -n 1)
case "$current" in
    ''|*[!0-9]*) exit 0 ;;
esac
[ "$current" -gt 0 ] || exit 0

target=$((current + step))
[ "$target" -ge 1 ] || exit 0

# Do nothing when the focused workspace has no container to move.
if ! swaymsg -t get_tree -r |
    jq -e '.. | objects | select(.focused == true and
        (.pid != null or .window != null or .app_id != null))' >/dev/null; then
    exit 0
fi

swaymsg "move container to workspace number $target" >/dev/null
swaymsg "workspace number $target" >/dev/null
