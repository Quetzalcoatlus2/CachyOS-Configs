#!/usr/bin/env bash
# Hourly Waybar update indicator.
#
# Reports repository, AUR/devel and (when installed) Flatpak updates, keeps a
# small state file, and sends a desktop notification only when the pending
# update set changes. Failures are surfaced in the Waybar tooltip instead of
# being silently reported as "0 updates".

set -u

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-updates"
STATE_FILE="$STATE_DIR/packages"
LOCK_FILE="$STATE_DIR/check.lock"
NOTIFY_ICON="system-software-update"

mkdir -p -- "$STATE_DIR" 2>/dev/null || exit 0

# Skip while a package transaction is in progress; Waybar keeps the previous
# output, which is less confusing than a transient error.
[[ -e /var/lib/pacman/db.lck ]] && exit 0

# Never let two hourly runs overlap.
exec 9>"$LOCK_FILE" || exit 0
flock -n 9 || exit 0

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/waybar-updates.XXXXXX")" || exit 0
trap 'rm -rf -- "$tmpdir"' EXIT

repo_out="$tmpdir/repo.out"
aur_out="$tmpdir/aur.out"
flatpak_out="$tmpdir/flatpak.out"

repo_count=0
aur_count=0
flatpak_count=0
flatpak_state=""

errors=()
warnings=()

# Repository updates.
checkupdates >"$repo_out" 2>"$tmpdir/repo.err"
repo_rc=$?
case $repo_rc in
    0)
        repo_count=$(grep -c . "$repo_out" 2>/dev/null || true)
        ;;
    2)
        repo_count=0
        ;;
    *)
        repo_count=0
        message=$(head -n 1 "$tmpdir/repo.err" 2>/dev/null)
        errors+=("Repository check failed (exit $repo_rc)${message:+: $message}")
        ;;
esac

# AUR updates. paru returns 1 with no output when there is nothing to upgrade;
# only treat stderr as an error when it actually looks like a failure.
paru -Qum >"$aur_out" 2>"$tmpdir/aur.err"
aur_rc=$?
if (( aur_rc == 0 )); then
    aur_count=$(grep -c . "$aur_out" 2>/dev/null || true)
elif (( aur_rc == 1 )) && ! grep -qiE 'error:|failed to|could not|unable to' "$tmpdir/aur.err" 2>/dev/null; then
    aur_count=0
else
    aur_count=0
    message=$(head -n 1 "$tmpdir/aur.err" 2>/dev/null)
    errors+=("AUR check failed (exit $aur_rc)${message:+: $message}")
fi

# Flatpak is optional; absence is not an error.
if command -v flatpak >/dev/null 2>&1; then
    if flatpak remote-ls --updates --columns=application >"$flatpak_out" 2>"$tmpdir/flatpak.err"; then
        flatpak_count=$(grep -c . "$flatpak_out" 2>/dev/null || true)
    elif grep -qiE 'no remote refs|no remotes' "$tmpdir/flatpak.err" 2>/dev/null; then
        # Flatpak is installed but has no remotes configured; treat as empty.
        flatpak_count=0
    else
        flatpak_count=0
        message=$(head -n 1 "$tmpdir/flatpak.err" 2>/dev/null)
        warnings+=("Flatpak check failed${message:+: $message}")
    fi
else
    flatpak_state="not installed"
fi

total=$((repo_count + aur_count + flatpak_count))

# Build the comparable update set. Prefixes keep identically named packages
# from different sources distinct.
state_file="$tmpdir/packages"
{
    sed 's/^/[repo] /' "$repo_out" 2>/dev/null
    sed 's/^/[aur] /' "$aur_out" 2>/dev/null
    sed 's/^/[flatpak] /' "$flatpak_out" 2>/dev/null
} | LC_ALL=C sort >"$state_file"

# Only trust state changes when every enabled source was queried successfully.
state_ok=1
(( ${#errors[@]} == 0 )) || state_ok=0
(( ${#warnings[@]} == 0 )) || state_ok=0

if (( state_ok )); then
    if [[ ! -f $STATE_FILE ]]; then
        # First run: remember the baseline without notifying.
        cp -- "$state_file" "$STATE_FILE"
    elif ! cmp -s -- "$state_file" "$STATE_FILE"; then
        old_total=$(wc -l <"$STATE_FILE" 2>/dev/null || printf '0')
        new_total=$(wc -l <"$state_file" 2>/dev/null || printf '0')

        if (( total > 0 )); then
            if (( old_total == 0 )); then
                title="Updates available: $total"
            else
                title="Available updates changed: $total"
            fi

            body="Repository: $repo_count"
            body+=$'\n'"AUR/devel: $aur_count"
            (( flatpak_count > 0 )) && body+=$'\n'"Flatpak: $flatpak_count"

            preview=$(awk 'NF >= 2 { print $2 }' "$state_file" | head -n 5)
            if [[ -n $preview ]]; then
                body+=$'\n\n'"$(printf '%s\n' "$preview" | sed 's/^/• /')"
                if (( new_total > 5 )); then
                    body+=$'\n'"… and $((new_total - 5)) more"
                fi
            fi
            notify-send -a "System Updates" -i "$NOTIFY_ICON" "$title" "$body" 2>/dev/null || true
        elif (( old_total > 0 )); then
            notify-send -a "System Updates" -i "$NOTIFY_ICON" \
                "System is up to date" \
                "No repository, AUR or Flatpak updates remain." 2>/dev/null || true
        fi

        cp -- "$state_file" "$STATE_FILE"
    fi
fi

if (( ${#errors[@]} > 0 )); then
    class="error"
else
    if (( total == 0 )); then
        class="synced"
    elif (( total <= 10 )); then
        class="low"
    elif (( total <= 35 )); then
        class="medium"
    else
        class="high"
    fi
fi

text="$total"
if (( total == 0 && ${#errors[@]} > 0 )); then
    text="?"
fi

tooltip="System Package Synchronization"
tooltip+=$'\n'"• Available updates: $total ($repo_count repository, $aur_count AUR/devel"
if (( flatpak_count > 0 )); then
    tooltip+=", $flatpak_count Flatpak"
elif [[ $flatpak_state == "not installed" ]]; then
    tooltip+="; Flatpak not installed"
fi
tooltip+=")"
tooltip+=$'\n'"• Last checked: $(date '+%Y-%m-%d %H:%M')"
tooltip+=$'\n'"• Check frequency: hourly"

if (( ${#warnings[@]} > 0 )); then
    tooltip+=$'\n\n'"Warnings:"
    for warning in "${warnings[@]}"; do
        tooltip+=$'\n'"• $warning"
    done
fi

if (( ${#errors[@]} > 0 )); then
    tooltip+=$'\n\n'"Errors:"
    for error in "${errors[@]}"; do
        tooltip+=$'\n'"• $error"
    done
fi

tooltip+=$'\n\n'"Click: run the full update and maintenance workflow."

if command -v jq >/dev/null 2>&1; then
    jq -cn --arg text "$text" --arg class "$class" --arg tooltip "$tooltip" \
        '{text: $text, class: $class, tooltip: $tooltip}'
else
    # Minimal fallback; jq is part of the expected tool set.
    escaped=$(printf '%s' "$tooltip" | sed ':a;N;$!ba;s/\\/\\\\/g;s/"/\\"/g;s/$/\\n/;s/\\n$//')
    printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$class" "$escaped"
fi

exit 0
