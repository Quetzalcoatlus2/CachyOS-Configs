#!/usr/bin/env bash
# One-click system update and maintenance workflow for the Waybar update widget.
#
# Sequence:
#   1. refuse to run alongside another package transaction
#   2. report repository, AUR/devel and optional Flatpak updates
#   3. let Paru present Arch news and the coloured upgrade plan
#   4. run the combined repository + AUR upgrade
#   5. offer orphan removal
#   6. offer package-cache cleanup with an explicit retention policy
#   7. review .pacnew/.pacsave files
#   8. report services that may need a restart
#   9. compare the running kernel with its installed package and check fwupd
#  10. refresh Waybar and print the result
#
# Usage: update-all.sh [--dry-run] [--help]

set -u

usage() {
    cat <<'EOF'
Usage: update-all.sh [--dry-run] [--help]

  --dry-run, -n   Inspect and report only; change nothing.
  --help, -h      Show this help.

Environment:
  UPDATE_ALL_NO_PAUSE=1   Do not wait for Enter before closing.
  NO_COLOR=1              Disable ANSI colours.
EOF
}

DRY_RUN=0
case "${1:-}" in
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    '') ;;
    *) usage >&2; exit 2 ;;
esac

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
    BOLD=$'\e[1m'
    DIM=$'\e[2m'
    RED=$'\e[31m'
    GREEN=$'\e[32m'
    YELLOW=$'\e[33m'
    BLUE=$'\e[34m'
    CYAN=$'\e[36m'
    RESET=$'\e[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' BLUE='' CYAN='' RESET=''
fi

section() {
    printf '\n%s\n' "${BOLD}${BLUE}== $* ==${RESET}"
    printf '%s\n' "${DIM}────────────────────────────────────────────────────────────${RESET}"
}

info() { printf '%s\n' "${CYAN}•${RESET} $*"; }
ok()   { printf '%s\n' "${GREEN}✓${RESET} $*"; }
warn() { printf '%s\n' "${YELLOW}!${RESET} $*"; }
err()  { printf '%s\n' "${RED}✗${RESET} $*" >&2; }

PAUSE=1
[[ ${UPDATE_ALL_NO_PAUSE:-0} == 1 ]] && PAUSE=0
WORKDIR=""

cleanup() {
    local rc=$?
    trap - EXIT INT TERM
    [[ -n $WORKDIR ]] && rm -rf -- "$WORKDIR"
    if (( PAUSE )) && [[ -t 0 && -t 1 ]]; then
        printf '\n%sPress Enter to close...%s' "$DIM" "$RESET"
        read -r _ || true
        printf '\n'
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ -n ${XDG_RUNTIME_DIR:-} ]]; then
    LOCK_FILE="$XDG_RUNTIME_DIR/waybar-update-all-$(id -u).lock"
else
    LOCK_FILE="/tmp/waybar-update-all-$(id -u).lock"
fi
if ! exec 9>"$LOCK_FILE"; then
    err "Cannot create workflow lock: $LOCK_FILE"
    exit 1
fi
if ! flock -n 9; then
    err "Another update workflow is already running."
    exit 1
fi

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/waybar-update-all.XXXXXX") || exit 1

# Keep the editor usable for Paru PKGBUILD review and sudo -e.
export EDITOR="${EDITOR:-micro}"
export VISUAL="${VISUAL:-$EDITOR}"

if command -v diff >/dev/null 2>&1 && diff --help 2>/dev/null | grep -q -- '--color'; then
    DIFF_COLOR=1
else
    DIFF_COLOR=0
fi

# Globals filled by collect_counts.
C_REPO=0
C_AUR=0
C_FLATPAK=0
C_DEVEL=0
C_TOTAL=0
C_ERRORS=()
C_WARNINGS=()
FLATPAK_AVAILABLE=0

# Result globals.
INIT_REPO=0
INIT_AUR=0
INIT_FLATPAK=0
INIT_TOTAL=0
FINAL_REPO=0
FINAL_AUR=0
FINAL_FLATPAK=0
FINAL_TOTAL=0
FINAL_ERRORS=()
UPGRADE_STATUS="not started"
ORPHAN_STATUS="not checked"
CACHE_STATUS="not checked"
PACNEW_REMAINING=0
SERVICE_FAILED=0
SERVICE_STATUS="not checked"
RESTART_UNITS=()
REBOOT_NEEDED=0
REBOOT_STATUS="not checked"
REVIEW_QUIT=0

check_other_updaters() {
    local found=0 name line
    if [[ -e /var/lib/pacman/db.lck ]]; then
        err "Pacman database lock exists: /var/lib/pacman/db.lck"
        found=1
    fi
    for name in paru pacman pikaur yay topgrade; do
        while IFS= read -r line; do
            [[ -n $line ]] || continue
            # checkupdates uses its own temporary pacman database; do not
            # mistake its short-lived pacman child for a system updater.
            [[ $name == pacman && $line == *checkup-db* ]] && continue
            err "Another updater is running: $line"
            found=1
        done < <(pgrep -a -x "$name" 2>/dev/null || true)
    done
    (( found == 0 ))
}

collect_counts() {
    local dir=$1
    local rc message

    mkdir -p -- "$dir"
    C_REPO=0
    C_AUR=0
    C_FLATPAK=0
    C_DEVEL=0
    C_TOTAL=0
    C_ERRORS=()
    C_WARNINGS=()
    FLATPAK_AVAILABLE=0

    CHECKUPDATES_DB="$dir/checkup-db" checkupdates >"$dir/repo.out" 2>"$dir/repo.err"
    rc=$?
    case $rc in
        0) C_REPO=$(grep -c . "$dir/repo.out" 2>/dev/null || true) ;;
        2) C_REPO=0 ;;
        *)
            C_REPO=0
            message=$(head -n 1 "$dir/repo.err" 2>/dev/null)
            C_ERRORS+=("Repository check failed (exit $rc)${message:+: $message}")
            ;;
    esac

    paru -Qum >"$dir/aur.out" 2>"$dir/aur.err"
    rc=$?
    if (( rc == 0 )); then
        C_AUR=$(grep -c . "$dir/aur.out" 2>/dev/null || true)
    elif (( rc == 1 )) && ! grep -qiE 'error:|failed to|could not|unable to' "$dir/aur.err" 2>/dev/null; then
        C_AUR=0
    else
        C_AUR=0
        message=$(head -n 1 "$dir/aur.err" 2>/dev/null)
        C_ERRORS+=("AUR check failed (exit $rc)${message:+: $message}")
    fi

    C_DEVEL=$(paru -Qmq 2>/dev/null | grep -Ec -- '-(git|cvs|svn|bzr|darcs|hg|fossil)$' || true)

    if command -v flatpak >/dev/null 2>&1; then
        FLATPAK_AVAILABLE=1
        if flatpak remote-ls --updates --columns=application >"$dir/flatpak.out" 2>"$dir/flatpak.err"; then
            C_FLATPAK=$(grep -c . "$dir/flatpak.out" 2>/dev/null || true)
        elif grep -qiE 'no remote refs|no remotes' "$dir/flatpak.err" 2>/dev/null; then
            # Flatpak is installed but has no remotes configured; treat as empty.
            C_FLATPAK=0
        else
            C_FLATPAK=0
            message=$(head -n 1 "$dir/flatpak.err" 2>/dev/null)
            C_WARNINGS+=("Flatpak check failed${message:+: $message}")
        fi
    fi

    C_TOTAL=$((C_REPO + C_AUR + C_FLATPAK))
}

print_counts() {
    printf '  %-24s %s\n' "Repository updates" "$C_REPO"
    if (( C_DEVEL > 0 )); then
        printf '  %-24s %s (%s devel package(s) tracked; checked during upgrade)\n' \
            "AUR updates" "$C_AUR" "$C_DEVEL"
    else
        printf '  %-24s %s\n' "AUR updates" "$C_AUR"
    fi
    if (( FLATPAK_AVAILABLE )); then
        printf '  %-24s %s\n' "Flatpak updates" "$C_FLATPAK"
    else
        printf '  %-24s %s\n' "Flatpak" "not installed (optional)"
    fi
    printf '  %-24s %s\n' "Total" "$C_TOTAL"

    for message in "${C_WARNINGS[@]}"; do
        warn "$message"
    done
    for message in "${C_ERRORS[@]}"; do
        err "$message"
    done
}

auth_sudo() {
    (( EUID == 0 )) && return 0
    info "Administrative privileges are required for the upgrade and maintenance steps."
    if ! sudo -v; then
        err "sudo authentication failed."
        return 1
    fi
}

ask_yes_no() {
    local prompt=$1 answer
    printf '%s [y/N] ' "$prompt"
    read -r answer || answer=""
    case $answer in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

show_diff() {
    local old=$1 new=$2
    if cmp -s -- "$old" "$new"; then
        info "Files are identical."
        return 0
    fi
    if (( DIFF_COLOR )); then
        if command -v less >/dev/null 2>&1 && [[ -t 1 ]]; then
            diff -u --color=always -- "$old" "$new" | less -R
        else
            diff -u --color=always -- "$old" "$new" || true
        fi
    else
        if command -v less >/dev/null 2>&1 && [[ -t 1 ]]; then
            diff -u -- "$old" "$new" | less -R
        else
            diff -u -- "$old" "$new" || true
        fi
    fi
}

view_path() {
    local path=$1
    if command -v less >/dev/null 2>&1 && [[ -t 1 ]]; then
        less -R -- "$path"
    else
        sed -n '1,240p' -- "$path"
    fi
}

edit_path() {
    local path=$1 micro_path
    micro_path=$(command -v micro 2>/dev/null || true)
    if [[ -n $micro_path ]]; then
        if ! sudo "$micro_path" -- "$path"; then
            warn "Editor exited with an error; $path was not changed by this workflow."
        fi
    elif ! sudo -e -- "$path"; then
        warn "Editor exited with an error; $path was not changed by this workflow."
    fi
}

# libalpm logs "pkg: local (x) is newer than repo (y)" when the installed
# package is newer than the first repo that provides it. With the CachyOS v3
# overlay, core/extra/testing and the generic cachyos repo this is expected:
# pacman-filtered already adds the newest available repo version as an explicit
# target. Paru prefixes these libalpm notices with "::" on stderr, so drop only
# those lines and keep real warnings and errors.
filter_paru_stderr() {
    awk '
        {
            clean = $0
            gsub(/\033\[[0-9;]*[A-Za-z]/, "", clean)
            if (clean ~ /^(::|warning:) .*: local \([^)]*\) is newer than /) {
                next
            }
            print
            fflush()
        }
    '
}

review_one_pacnew() {
    local file=$1
    local base=${file%.pacnew}
    local action answer backup

    printf '\n%s%s%s\n' "$BOLD" "$file" "$RESET"
    if [[ -L $base ]]; then
        warn "$base is a symlink; replacing it could break the link target. Prefer edit/merge."
    fi
    if [[ -f $base ]]; then
        show_diff "$base" "$file"
    else
        warn "Current file $base does not exist."
    fi

    while :; do
        printf 'Action [r]eplace current / [e]dit current / [v]iew new / [k]eep current+remove new / [s]kip / [q]uit: '
        read -r action || { printf '\n'; return; }
        action=${action:0:1}
        printf '\n'
        case $action in
            r|R)
                if [[ -L $base ]]; then
                    warn "Refusing automatic replacement of a symlink; edit or merge manually."
                    continue
                fi
                if [[ -e $base && ! -f $base ]]; then
                    warn "Refusing to replace $base because it is not a regular file."
                    continue
                fi
                if [[ -e $base ]]; then
                    ask_yes_no "Replace $base with $file? A timestamped backup will be kept." || {
                        info "Replacement cancelled."
                        continue
                    }
                else
                    ask_yes_no "Create $base from $file?" || {
                        info "Creation cancelled."
                        continue
                    }
                fi
                backup=""
                if [[ -e $base ]]; then
                    backup="$base.pacorig.$(date +%Y%m%d-%H%M%S)"
                    if ! sudo cp -a -- "$base" "$backup"; then
                        err "Could not create backup $backup; $file was left in place."
                        continue
                    fi
                fi
                if sudo cp -- "$file" "$base" && sudo rm -f -- "$file"; then
                    if [[ -n $backup ]]; then
                        ok "Replaced $base (backup: $backup)."
                    else
                        ok "Created $base from $file."
                    fi
                else
                    err "Replacement failed; $file was left in place."
                fi
                return
                ;;
            e|E)
                if [[ -f $base ]]; then
                    edit_path "$base"
                else
                    warn "Current file does not exist; use [v]iew or restore from $file."
                fi
                ;;
            v|V)
                view_path "$file"
                ;;
            k|K)
                if ! ask_yes_no "Keep $base and delete $file? This discards the packaged version."; then
                    info "Kept $file."
                    continue
                fi
                if sudo rm -f -- "$file"; then
                    ok "Removed $file; kept $base."
                else
                    err "Could not remove $file."
                fi
                return
                ;;
            s|S)
                info "Skipped $file."
                return
                ;;
            q|Q)
                REVIEW_QUIT=1
                return
                ;;
            *)
                warn "Unknown action."
                ;;
        esac
    done
}

review_one_pacsave() {
    local file=$1
    local base=${file%.pacsave}
    local action

    printf '\n%s%s%s\n' "$BOLD" "$file" "$RESET"
    if [[ -f $base ]]; then
        show_diff "$base" "$file"
    else
        warn "No current $base exists; this is a saved configuration from a removed package."
    fi

    while :; do
        printf 'Action [r]estore / [e]dit save / [v]iew save / [d]elete save / [s]kip / [q]uit: '
        read -r action || { printf '\n'; return; }
        action=${action:0:1}
        printf '\n'
        case $action in
            r|R)
                if [[ -e $base || -L $base ]]; then
                    warn "Current path $base already exists; refusing to overwrite it. Merge manually or use the .pacnew flow."
                    continue
                fi
                if ! ask_yes_no "Restore $file to $base?"; then
                    info "Restore cancelled."
                    continue
                fi
                if sudo cp -a -- "$file" "$base" && sudo rm -f -- "$file"; then
                    ok "Restored $base from $file."
                else
                    err "Restore failed; $file was left in place."
                fi
                return
                ;;
            e|E)
                edit_path "$file"
                ;;
            v|V)
                view_path "$file"
                ;;
            d|D)
                if ! ask_yes_no "Delete $file permanently?"; then
                    info "Delete cancelled."
                    continue
                fi
                if sudo rm -f -- "$file"; then
                    ok "Deleted $file."
                else
                    err "Could not delete $file."
                fi
                return
                ;;
            s|S)
                info "Skipped $file."
                return
                ;;
            q|Q)
                REVIEW_QUIT=1
                return
                ;;
            *)
                warn "Unknown action."
                ;;
        esac
    done
}

review_configs() {
    section "Configuration file review"
    local -a candidates=()
    if command -v pacdiff >/dev/null 2>&1; then
        mapfile -t candidates < <(pacdiff -o 2>/dev/null || true)
    else
        mapfile -t candidates < <(find /etc -xdev \( -name '*.pacnew' -o -name '*.pacsave' \) -print 2>/dev/null | LC_ALL=C sort)
    fi

    PACNEW_REMAINING=${#candidates[@]}
    if (( PACNEW_REMAINING == 0 )); then
        ok "No .pacnew or .pacsave files found."
        return
    fi

    printf 'Pending configuration files (%d):\n' "$PACNEW_REMAINING"
    printf '  %s\n' "${candidates[@]}"

    if (( DRY_RUN )); then
        info "[dry-run] Would review each file above interactively."
        return
    fi

    warn "Review carefully before replacing a file; packaged defaults can drop local settings."
    REVIEW_QUIT=0
    local file
    for file in "${candidates[@]}"; do
        [[ -e $file ]] || continue
        case $file in
            *.pacnew) review_one_pacnew "$file" ;;
            *.pacsave) review_one_pacsave "$file" ;;
        esac
        (( REVIEW_QUIT )) && break
    done

    if command -v pacdiff >/dev/null 2>&1; then
        mapfile -t candidates < <(pacdiff -o 2>/dev/null || true)
    else
        mapfile -t candidates < <(find /etc -xdev \( -name '*.pacnew' -o -name '*.pacsave' \) -print 2>/dev/null | LC_ALL=C sort)
    fi
    PACNEW_REMAINING=${#candidates[@]}
    if (( PACNEW_REMAINING > 0 )); then
        warn "$PACNEW_REMAINING configuration file(s) still need review."
    else
        ok "All configuration files reviewed."
    fi
}

review_orphans() {
    section "Orphan packages"
    local -a orphans=()
    mapfile -t orphans < <(/usr/bin/pacman -Qtdq 2>/dev/null || true)

    if (( ${#orphans[@]} == 0 )); then
        ok "No orphan packages found."
        ORPHAN_STATUS="none"
        return
    fi

    printf 'Orphan packages (%d):\n' "${#orphans[@]}"
    printf '  %s\n' "${orphans[@]}"

    if (( DRY_RUN )); then
        info "[dry-run] Would offer to remove these with: sudo pacman -Rns"
        ORPHAN_STATUS="dry-run (${#orphans[@]} listed)"
        return
    fi

    if ! ask_yes_no "Remove these orphan packages with pacman -Rns?"; then
        info "Orphan removal skipped."
        ORPHAN_STATUS="skipped (${#orphans[@]} pending)"
        return
    fi

    if sudo /usr/bin/pacman -Rns "${orphans[@]}"; then
        ok "Removed ${#orphans[@]} orphan package(s)."
        ORPHAN_STATUS="removed ${#orphans[@]}"
    else
        err "Orphan removal failed."
        ORPHAN_STATUS="removal failed"
    fi
}

review_cache() {
    section "Package cache"
    info "Retention policy: keep the 3 most recent versions of each package; keep anything newer than 30 days."
    info "AUR build caches are separate; use 'paru -Sc' explicitly if they need cleaning."

    if (( DRY_RUN )); then
        info "[dry-run] Would run: sudo paccache -r -k 3 --min-mtime '30 days ago'"
        CACHE_STATUS="dry-run"
        return
    fi

    local dry="$WORKDIR/paccache.dry"
    if ! sudo paccache -d -k 3 --min-mtime '30 days ago' >"$dry" 2>&1; then
        err "paccache dry run failed:"
        sed -n '1,40p' "$dry" >&2
        CACHE_STATUS="check failed"
        return
    fi

    printf '%s\n' "$(cat "$dry")"
    if grep -q 'no candidate packages' "$dry"; then
        ok "No cache candidates under the retention policy."
        CACHE_STATUS="nothing to remove"
        return
    fi

    if ! ask_yes_no "Remove the candidate packages listed above?"; then
        info "Cache cleanup skipped."
        CACHE_STATUS="skipped"
        return
    fi

    if sudo paccache -r -k 3 --min-mtime '30 days ago'; then
        ok "Package cache cleaned using the stated retention policy."
        CACHE_STATUS="cleaned"
    else
        err "Cache cleanup failed."
        CACHE_STATUS="cleanup failed"
    fi
}

service_diagnostic() {
    section "Service restart diagnostic"
    local -a failed=()
    mapfile -t failed < <(systemctl --failed --no-legend --plain 2>/dev/null || true)
    SERVICE_FAILED=${#failed[@]}
    if (( SERVICE_FAILED > 0 )); then
        warn "Failed system units:"
        printf '  %s\n' "${failed[@]}"
    else
        ok "No failed system units."
    fi

    if (( DRY_RUN )); then
        info "[dry-run] Would scan running processes for deleted files from /usr."
        SERVICE_STATUS="dry-run (${SERVICE_FAILED} failed unit(s))"
        return
    fi

    if ! command -v lsof >/dev/null 2>&1; then
        warn "lsof is not installed; cannot check for processes using replaced files."
        SERVICE_STATUS="lsof missing"
        return
    fi

    local lsof_out="$WORKDIR/lsof.out"
    if (( EUID == 0 )); then
        lsof +L1 -F pcn >"$lsof_out" 2>/dev/null || true
    else
        sudo lsof +L1 -F pcn >"$lsof_out" 2>/dev/null || true
    fi

    declare -A pid_cmd=()
    declare -A pid_path=()
    local pid="" cmd="" line path
    while IFS= read -r line; do
        case $line in
            p*) pid=${line#p}; cmd="" ;;
            c*) cmd=${line#c} ;;
            n*)
                path=${line#n}
                [[ $path == /usr/* ]] || continue
                if [[ -n $pid && -z ${pid_path[$pid]:-} ]]; then
                    pid_cmd[$pid]=$cmd
                    pid_path[$pid]=$path
                fi
                ;;
        esac
    done <"$lsof_out"

    if (( ${#pid_path[@]} == 0 )); then
        ok "No running process is holding a deleted file from /usr."
        SERVICE_STATUS="none (${SERVICE_FAILED} failed unit(s))"
        return
    fi

    warn "Processes holding deleted files from /usr (best-effort restart candidates):"
    declare -A seen_units=()
    RESTART_UNITS=()
    local count=0 unit uunit
    for pid in "${!pid_path[@]}"; do
        if (( count >= 30 )); then
            info "More than 30 processes matched; only the first 30 are shown."
            break
        fi

        unit=$(systemctl status "$pid" --no-pager -n 0 2>/dev/null \
            | sed -n '1{s/^[^[:alnum:]]*//;s/[[:space:]].*//;p}')
        if [[ -z $unit || $unit == user@* ]]; then
            uunit=$(systemctl --user status "$pid" --no-pager -n 0 2>/dev/null \
                | sed -n '1{s/^[^[:alnum:]]*//;s/[[:space:]].*//;p}')
            [[ -n $uunit ]] && unit=$uunit
        fi

        if (( pid == 1 )); then
            warn "PID 1 is using a deleted file; a reboot is safer than restarting systemd."
        fi

        if [[ -n $unit && $unit == *.service && -z ${seen_units[$unit]:-} ]]; then
            seen_units[$unit]=1
            RESTART_UNITS+=("$unit")
        fi

        printf '  %-32s PID %-7s %s\n' \
            "${unit:-${pid_cmd[$pid]:-unknown}}" "$pid" "${pid_path[$pid]}"
        count=$((count + 1))
    done

    printf '\nRestart only the affected units, for example:\n'
    printf '  sudo systemctl try-restart <unit>       # system services\n'
    printf '  systemctl --user try-restart <unit>     # user services\n'
    info "No services were restarted automatically."

    SERVICE_STATUS="${#RESTART_UNITS[@]} unit(s) to review"
    (( SERVICE_FAILED > 0 )) && SERVICE_STATUS+=", ${SERVICE_FAILED} failed"
    return 0
}

kernel_check() {
    section "Kernel and reboot check"
    local running pkg installed kernel_reboot=0 fwupd_reboot=0
    running=$(uname -r)
    pkg=""

    if [[ -e /usr/lib/modules/$running/vmlinuz ]]; then
        pkg=$(/usr/bin/pacman -Qoq "/usr/lib/modules/$running/vmlinuz" 2>/dev/null || true)
    fi

    if [[ -z $pkg ]]; then
        local name version
        while read -r name version; do
            [[ $name == linux* ]] || continue
            if [[ $running == "$version" || $running == "$version"-* ]]; then
                pkg=$name
                installed=$version
                break
            fi
        done < <(/usr/bin/pacman -Q 2>/dev/null)
    fi

    if [[ -n $pkg ]]; then
        installed=$(/usr/bin/pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')
        if [[ -n $installed && ( $running == "$installed" || $running == "$installed"-* ) ]]; then
            ok "Running kernel $running matches installed package $pkg $installed."
        else
            warn "Running kernel $running does not match installed package $pkg $installed."
            kernel_reboot=1
        fi
    else
        warn "Running kernel $running is not owned by an installed kernel package."
        kernel_reboot=1
    fi

    info "Installed kernel module trees:"
    local dir owner
    for dir in /usr/lib/modules/*; do
        [[ -d $dir ]] || continue
        owner=$(/usr/bin/pacman -Qoq "$dir/vmlinuz" 2>/dev/null || true)
        printf '  %-42s %s\n' "${dir##*/}" "${owner:-unknown package}"
    done

    if command -v fwupdmgr >/dev/null 2>&1; then
        if timeout 15 fwupdmgr get-devices 2>/dev/null | grep -q 'Needs reboot'; then
            fwupd_reboot=1
            warn "fwupd reports a device with 'Update State: Needs reboot'."
        fi
    fi

    if (( kernel_reboot || fwupd_reboot )); then
        REBOOT_NEEDED=1
        REBOOT_STATUS="recommended"
        warn "Reboot recommended after finishing. No reboot was performed automatically."
    else
        REBOOT_NEEDED=0
        REBOOT_STATUS="not required"
        ok "No reboot required for the running kernel."
    fi
}

refresh_waybar() {
    section "Waybar refresh"
    if (( DRY_RUN )); then
        info "[dry-run] Would signal Waybar to re-run the update checker."
        return
    fi
    local -a pids=()
    mapfile -t pids < <(pgrep -u "$(id -u)" -x waybar 2>/dev/null || true)
    if (( ${#pids[@]} == 0 )); then
        info "Waybar is not running; nothing to refresh."
    elif kill -s RTMIN+8 "${pids[@]}" 2>/dev/null; then
        ok "Waybar update indicator refreshed."
    else
        warn "Could not signal Waybar to refresh."
    fi
}

print_summary() {
    section "Result"
    (( DRY_RUN )) && warn "DRY RUN: no packages, files, services or timers were changed."

    printf '  %-28s %s\n' "Upgrade" "$UPGRADE_STATUS"
    printf '  %-28s %s\n' "Updates at start" \
        "$INIT_TOTAL ($INIT_REPO repository, $INIT_AUR AUR, $INIT_FLATPAK Flatpak)"
    printf '  %-28s %s\n' "Updates after" \
        "$FINAL_TOTAL ($FINAL_REPO repository, $FINAL_AUR AUR, $FINAL_FLATPAK Flatpak)"
    printf '  %-28s %s\n' "Orphans" "$ORPHAN_STATUS"
    printf '  %-28s %s\n' "Package cache" "$CACHE_STATUS"
    printf '  %-28s %s\n' "Config files remaining" "$PACNEW_REMAINING"
    printf '  %-28s %s\n' "Services" "$SERVICE_STATUS"
    printf '  %-28s %s\n' "Reboot" "$REBOOT_STATUS"

    if (( ${#FINAL_ERRORS[@]} > 0 )); then
        printf '\n'
        for message in "${FINAL_ERRORS[@]}"; do
            err "$message"
        done
    fi

    if (( REBOOT_NEEDED )); then
        printf '\n%sReboot when convenient to finish kernel or firmware changes.%s\n' "$YELLOW" "$RESET"
    fi
}

main() {
    printf '%s\n' "${BOLD}${BLUE}System update and maintenance${RESET}"
    (( DRY_RUN )) && warn "Dry run: inspection only."

    section "Updater check"
    if ! check_other_updaters; then
        err "Another package transaction is in progress. Wait for it to finish and rerun."
        UPGRADE_STATUS="not started (updater busy)"
        FINAL_REPO=$INIT_REPO
        FINAL_AUR=$INIT_AUR
        FINAL_FLATPAK=$INIT_FLATPAK
        FINAL_TOTAL=$INIT_TOTAL
        FINAL_ERRORS=("Workflow aborted because another updater is running.")
        print_summary
        return 1
    fi
    ok "No other updater is running."

    section "Available updates"
    collect_counts "$WORKDIR/initial"
    INIT_REPO=$C_REPO
    INIT_AUR=$C_AUR
    INIT_FLATPAK=$C_FLATPAK
    INIT_TOTAL=$C_TOTAL
    print_counts

    section "Arch news"
    info "Paru will show any unread Arch news before the upgrade (NewsOnUpgrade)."
    info "The coloured package plan and Paru's confirmation prompt follow."

    section "Upgrade"
    if (( DRY_RUN )); then
        info "[dry-run] Would run: paru --pacman /usr/local/bin/pacman-filtered -Syu"
        UPGRADE_STATUS="skipped (dry-run)"
    else
        if ! auth_sudo; then
            UPGRADE_STATUS="not started (sudo failed)"
            FINAL_REPO=$INIT_REPO
            FINAL_AUR=$INIT_AUR
            FINAL_FLATPAK=$INIT_FLATPAK
            FINAL_TOTAL=$INIT_TOTAL
            FINAL_ERRORS=("Workflow aborted because sudo authentication failed.")
            print_summary
            return 1
        fi

        paru --pacman /usr/local/bin/pacman-filtered -Syu 2> >(filter_paru_stderr >&2)
        rc=$?
        if (( rc == 0 )); then
            UPGRADE_STATUS="success"
        else
            if (( rc == 130 )); then
                UPGRADE_STATUS="cancelled"
            else
                UPGRADE_STATUS="failed (exit $rc)"
            fi
            FINAL_REPO=$INIT_REPO
            FINAL_AUR=$INIT_AUR
            FINAL_FLATPAK=$INIT_FLATPAK
            FINAL_TOTAL=$INIT_TOTAL
            FINAL_ERRORS=("Upgrade did not complete; maintenance steps were skipped.")
            print_summary
            (( rc == 130 )) && return 130
            return 1
        fi
    fi

    review_orphans
    review_cache
    review_configs
    service_diagnostic
    kernel_check
    refresh_waybar

    section "Post-upgrade update check"
    if (( DRY_RUN )); then
        info "[dry-run] Skipping post-upgrade check; initial counts are shown in the summary."
        FINAL_REPO=$INIT_REPO
        FINAL_AUR=$INIT_AUR
        FINAL_FLATPAK=$INIT_FLATPAK
        FINAL_TOTAL=$INIT_TOTAL
        FINAL_ERRORS=()
    else
        collect_counts "$WORKDIR/final"
        FINAL_REPO=$C_REPO
        FINAL_AUR=$C_AUR
        FINAL_FLATPAK=$C_FLATPAK
        FINAL_TOTAL=$C_TOTAL
        FINAL_ERRORS=("${C_ERRORS[@]}")
        for message in "${C_WARNINGS[@]}"; do
            warn "$message"
        done
        if (( FINAL_TOTAL == 0 && ${#FINAL_ERRORS[@]} == 0 )); then
            ok "No repository, AUR or Flatpak updates remain."
        else
            warn "Post-upgrade check still reports $FINAL_TOTAL pending update(s)."
        fi
    fi

    print_summary
    return 0
}

main
exit $?
