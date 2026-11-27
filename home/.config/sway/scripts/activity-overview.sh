#!/usr/bin/env bash
# Garuda-style overviews for Sway, built on wofi instead of swayr.
#
#   activity-overview.sh windows     pick any open window
#   activity-overview.sh workspaces  pick an existing workspace
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
    notify-send -a Overview "$summary" "$body"
}

wofi=$(find_tool wofi) || {
    notify "Overview unavailable" "wofi is not installed."
    exit 1
}
jq=$(find_tool jq) || {
    notify "Overview unavailable" "jq is not installed."
    exit 1
}
swaymsg=$(find_tool swaymsg) || {
    notify "Overview unavailable" "swaymsg is not installed."
    exit 1
}

picker() {
    "$wofi" --dmenu --insensitive --cache-file=/dev/null \
        --prompt "$1" --width 900 --lines 16
}

case "${1:-windows}" in
    windows)
        mapfile -t rows < <(
            "$swaymsg" -t get_tree | "$jq" -r '
                [ .. | objects
                  | select(.type == "workspace"
                           and .name != "__i3_scratch"
                           and .name != "__sway_scratch") as $ws
                  | $ws | .. | objects
                  | select(.type == "con" and .pid != null and .name != null)
                  | { id: (.id | tostring),
                      workspace: (if ($ws.num // -1) > 0
                                  then ($ws.num | tostring)
                                  else $ws.name end),
                      workspace_name: $ws.name,
                      focused: (.focused // false),
                      app: (.app_id // .window_properties.class // "Window"),
                      title: (.name | gsub("[\\t\\n]"; " ")) }
                ]
                | sort_by(.workspace | tonumber? // 999)
                | .[]
                | [.id, .workspace, .workspace_name, (.focused | tostring),
                   .app, .title] | @tsv
            '
        )

        labels=()
        ids=()
        for row in "${rows[@]}"; do
            IFS=$'\t' read -r id workspace workspace_name focused app title <<< "$row"
            display="${workspace_name:-$workspace}  $app — $title"
            [[ $focused == true ]] && display+="  (current)"
            labels+=("$display")
            ids+=("$id")
        done
        if [[ ${#labels[@]} -eq 0 ]]; then
            notify "Activities" "No windows are open."
            exit 0
        fi

        choice=$(printf '%s\n' "${labels[@]}" | picker 'Activities')
        [[ -n $choice ]] || exit 0

        target=
        for i in "${!labels[@]}"; do
            if [[ ${labels[$i]} == "$choice" ]]; then
                target=${ids[$i]}
                break
            fi
        done
        [[ -n $target ]] || exit 0
        "$swaymsg" "[con_id=$target] focus" >/dev/null 2>&1 || true
        ;;

    workspaces)
        mapfile -t rows < <(
            "$swaymsg" -t get_workspaces | "$jq" -r '
                .[] | [(.num | tostring), .name, (.focused | tostring), .output]
                | @tsv
            '
        )

        labels=()
        targets=()
        for row in "${rows[@]}"; do
            IFS=$'\t' read -r num name focused output <<< "$row"
            label=${name:-$num}
            if [[ $num =~ ^[0-9]+$ ]] && (( num > 0 )); then
                targets+=("number:$num")
            else
                targets+=("name:$name")
            fi
            [[ $focused == true ]] && label+="  (current)"
            label+="  [$output]"
            labels+=("$label")
        done
        if [[ ${#labels[@]} -eq 0 ]]; then
            notify "Workspaces" "No workspaces exist yet."
            exit 0
        fi

        choice=$(printf '%s\n' "${labels[@]}" | picker 'Workspaces')
        [[ -n $choice ]] || exit 0

        target=
        for i in "${!labels[@]}"; do
            if [[ ${labels[$i]} == "$choice" ]]; then
                target=${targets[$i]}
                break
            fi
        done
        [[ -n $target ]] || exit 0

        case $target in
            number:*)
                "$swaymsg" "workspace number ${target#number:}" >/dev/null 2>&1 || true
                ;;
            name:*)
                name=${target#name:}
                escaped=${name//\\/\\\\}
                escaped=${escaped//\"/\\\"}
                "$swaymsg" "workspace \"$escaped\"" >/dev/null 2>&1 || true
                ;;
        esac
        ;;

    *)
        printf 'Usage: %s [windows|workspaces]\n' "${0##*/}" >&2
        exit 2
        ;;
esac
