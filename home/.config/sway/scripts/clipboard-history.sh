#!/usr/bin/env bash
# Clipboard history for Sway, backed by cliphist and wofi.
#
#   clipboard-history.sh pick     choose an entry and copy it again
#   clipboard-history.sh delete   delete one entry
#   clipboard-history.sh wipe     clear the whole history
set -u

# CachyOS installs these system-wide; the Ubuntu ThinkPad keeps private builds
# in ~/.local/bin, which Sway does not necessarily put in PATH.
find_tool() {
    local name=$1 candidate
    for candidate in \
        "$HOME/.local/bin/$name" \
        /usr/local/bin/"$name" \
        /usr/bin/"$name" \
        /usr/sbin/"$name"; do
        if [[ -x $candidate ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    command -v "$name" 2>/dev/null
}

notify() {
    local summary=$1 body=$2
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a Clipboard -i edit-paste "$summary" "$body"
}

cliphist=$(find_tool cliphist) || {
    notify "Clipboard history unavailable" "cliphist is not installed."
    exit 1
}
wofi=$(find_tool wofi) || {
    notify "Clipboard history unavailable" "wofi is not installed."
    exit 1
}
wl_copy=$(find_tool wl-copy) || {
    notify "Clipboard history unavailable" "wl-clipboard is not installed."
    exit 1
}

picker() {
    "$wofi" --dmenu --insensitive --cache-file=/dev/null \
        --prompt "$1" --width 760 --lines 14
}

history=$("$cliphist" list 2>/dev/null)
if [[ -z $history ]]; then
    case "${1:-pick}" in
        pick|delete) notify "Clipboard history" "Nothing has been copied yet." ;;
        wipe) notify "Clipboard history" "History is already empty." ;;
    esac
    exit 0
fi

case "${1:-pick}" in
    pick)
        choice=$(printf '%s\n' "$history" | picker 'Clipboard history')
        [[ -n $choice ]] || exit 0
        # wl-copy infers the MIME type, so images come back as images.
        printf '%s' "$choice" | "$cliphist" decode | "$wl_copy"
        ;;
    delete)
        choice=$(printf '%s\n' "$history" | picker 'Delete clipboard entry')
        [[ -n $choice ]] || exit 0
        printf '%s' "$choice" | "$cliphist" delete
        ;;
    wipe)
        choice=$(printf '%s\n' 'Cancel' 'Clear clipboard history' |
            picker 'Clear clipboard history?')
        [[ $choice == 'Clear clipboard history' ]] || exit 0
        "$cliphist" wipe
        notify "Clipboard history" "History cleared."
        ;;
    *)
        printf 'Usage: %s [pick|delete|wipe]\n' "${0##*/}" >&2
        exit 2
        ;;
esac
