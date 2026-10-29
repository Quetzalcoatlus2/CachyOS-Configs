#!/usr/bin/env bash
set -u

dry_run=0
case "${1:-}" in
    --dry-run|-n) dry_run=1 ;;
    --help|-h)
        printf 'Usage: update-all.sh [--dry-run]\nUpdates Ubuntu APT packages only; dry-run uses existing indexes without sudo.\n'
        exit 0 ;;
    '') ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
esac
if (( $# > 1 )); then
    printf 'Too many arguments\n' >&2
    exit 2
fi

finish() {
    local rc=$?
    trap - EXIT
    if (( ! dry_run )); then
        local pid
        while read -r pid; do
            kill -s RTMIN+8 "$pid" || printf 'Could not refresh Waybar PID %s\n' "$pid" >&2
        done < <(pgrep -u "$(id -u)" -x waybar)
    fi
    if (( rc != 0 )); then
        printf '\nUpdate workflow failed (exit %s). Review the errors above.\n' "$rc" >&2
    fi
    if [[ -t 0 && ${UPDATE_ALL_NO_PAUSE:-0} != 1 ]]; then
        printf '\nPress any key to close...'
        read -r -s -n 1
    fi
    exit "$rc"
}
trap finish EXIT

if [[ ${UPDATE_ALL_NO_BANNER:-0} != 1 ]] && command -v fastfetch >/dev/null 2>&1; then
    fastfetch || printf 'Fastfetch banner failed; continuing with APT.\n' >&2
fi
printf 'Ubuntu package updates\nPrivate builds, Snap and Flatpak are not included.\n'
if (( dry_run )); then
    printf '\nRead-only preview using existing package indexes:\n'
    apt-get -s --with-new-pkgs upgrade || exit "$?"
else
    sudo apt-get -o APT::Update::Error-Mode=any update || exit "$?"
    printf '\nReview the upgrade plan below; APT will ask before installing.\n'
    sudo apt-get --with-new-pkgs upgrade || exit "$?"
    if [[ -f /var/run/reboot-required ]]; then
        printf '\nA reboot is required; restart manually when convenient.\n'
    fi
    printf '\nAPT commands finished. Declined upgrades remain pending.\n'
fi
