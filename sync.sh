#!/usr/bin/env bash
set -euo pipefail
ROOT="${DOTFILES_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
[[ $EUID -ne 0 ]] || { echo "Run as your normal user; privileged operations use sudo." >&2; exit 1; }
ROOT="$(cd -- "$ROOT" && pwd)"
command="${1:-check}"
case "$command" in pull) command=collect ;; esac
case "$command" in check|validate|deploy|collect|setup-timers) ;; *) echo "Usage: $0 {check|validate|deploy [--dry-run]|collect|pull|setup-timers}"; exit 1 ;; esac
[[ $# -le 1 || ( $# -eq 2 && $command == deploy && $2 == --dry-run ) ]] || { echo "Unexpected arguments" >&2; exit 1; }
index="$(mktemp)"
trap 'rm -f -- "$index"' EXIT
git -C "$ROOT" ls-files --stage -z -- home/ system/ > "$index"
paths=(); modes=()
while IFS= read -r -d '' entry; do
    mode="${entry%% *}"
    rel="${entry#*$'\t'}"
    [[ $mode == 100644 || $mode == 100755 ]] || { echo "Unsupported Git mode: $rel" >&2; exit 1; }
    [[ $rel != *$'\n'* && $rel != *'/../'* ]] || exit 1
    paths+=("$rel"); modes+=("${mode:3}")
done < "$index"
[[ ${#paths[@]} -gt 0 ]] || { echo "No tracked home/system files found" >&2; exit 1; }
live_path() { case "$1" in home/*) printf '%s/%s' "$HOME" "${1#home/}" ;; system/*) printf '/%s' "${1#system/}" ;; esac; }
validate() {
    local rel first
    for rel in "${paths[@]}"; do
        [[ -f "$ROOT/$rel" && ! -L "$ROOT/$rel" ]] || { echo "Missing or symlinked source: $rel" >&2; return 1; }
        IFS= read -r first < "$ROOT/$rel" || true
        case "$first" in '#!'*bash*) bash -n "$ROOT/$rel" ;; '#!'*'/sh'*) sh -n "$ROOT/$rel" ;; esac
    done
    bash -n "$ROOT/sync.sh"
    zsh -n "$ROOT/home/.zshrc"
    python3 - "$ROOT" <<'PY'
import ast,json,re,sys
from pathlib import Path
root=Path(sys.argv[1])
def unique(pairs):
    result={}
    for key,value in pairs:
        if key in result: raise ValueError(f"Duplicate JSON key: {key}")
        result[key]=value
    return result
text=(root/'home/.config/waybar/config.jsonc').read_text()
text=re.sub(r'("(?:\\.|[^"\\])*")|//[^\n]*|/\*.*?\*/',lambda m:m.group(1) or '',text,flags=re.S)
text=re.sub(r'("(?:\\.|[^"\\])*")|,\s*(?=[}\]])',lambda m:m.group(1) or '',text)
json.loads(text,object_pairs_hook=unique)
fastfetch=(root/'home/.config/fastfetch/config.jsonc').read_text()
fastfetch=re.sub(r'("(?:\\.|[^"\\])*")|//[^\n]*|/\*.*?\*/',lambda m:m.group(1) or '',fastfetch,flags=re.S)
fastfetch=re.sub(r'("(?:\\.|[^"\\])*")|,\s*(?=[}\]])',lambda m:m.group(1) or '',fastfetch)
json.loads(fastfetch,object_pairs_hook=unique)
for base in ('home','system'):
    for path in (root/base).rglob('*.py'):
        data=path.read_text()
        if 'python' in data.split('\n',1)[0]: ast.parse(data,filename=str(path))
PY
    sway --validate -c "$ROOT/home/.config/sway/config"
    echo "Validated ${#paths[@]} tracked configuration files; this does not verify live deployment."
}
require_fifo() {
    [[ -f /usr/local/bin/snapper-fifo.py ]] || { echo "Existing FIFO script required; no replacement is supplied." >&2; return 1; }
    local key
    for key in NUMBER_CLEANUP TIMELINE_CREATE TIMELINE_CLEANUP EMPTY_PRE_POST_CLEANUP; do
        sudo grep -qE "^${key}=\"no\"$" /etc/snapper/configs/root || { echo "Unexpected Snapper policy: $key must remain no" >&2; return 1; }
    done
}
if [[ $command == check || $command == validate ]]; then validate; exit; fi
if [[ $command == setup-timers ]]; then
    require_fifo
    sudo grep -qE '^ExecStartPre=/usr/local/bin/snapper-fifo.py --apply --limit 100$' /etc/systemd/system/snapper-cleanup.service.d/zz-fifo.conf
    state="$HOME/.local/state/cachyos-config-backups"
    mkdir -p -- "$state"; chmod 700 "$state"
    record="$(mktemp "$state/timers-before-XXXXXXXX.txt")"
    for unit in snapper-timeline.timer snapper-cleanup.timer paccache.timer 'btrfs-scrub@-.timer'; do
        { printf '%s: ' "$unit"; systemctl is-enabled "$unit" || true; } >> "$record"
    done
    sudo systemctl daemon-reload
    sudo systemctl disable --now snapper-timeline.timer
    sudo systemctl enable --now snapper-cleanup.timer paccache.timer 'btrfs-scrub@-.timer'
    echo "Timer setup complete; previous enablement states: $record"
    echo "No cleanup service or snapshot deletion was explicitly started."
    exit
fi
if [[ $command == deploy ]]; then
    validate
    if [[ ${2:-} == --dry-run ]]; then
        for rel in "${paths[@]}"; do printf '%s -> %s\n' "$ROOT/$rel" "$(live_path "$rel")"; done
        echo "Dry run only; no files, timers or settings changed."
        exit
    fi
    sudo -v
    require_fifo
fi
for rel in "${paths[@]}"; do
    target="$(live_path "$rel")"
    [[ $command == deploy ]] || target="$ROOT/$rel"
    [[ ! -L $target ]] || { echo "Refusing to overwrite symlink: $target" >&2; exit 1; }
done
state="$HOME/.local/state/cachyos-config-backups"
mkdir -p -- "$state"; chmod 700 "$state"
backup="$(mktemp -d "$state/$(date +%Y%m%d-%H%M%S)-XXXXXXXX")"
chmod 700 "$backup"
for i in "${!paths[@]}"; do
    rel="${paths[$i]}"; live="$(live_path "$rel")"
    if [[ $command == deploy ]]; then src="$ROOT/$rel"; dst="$live"; else src="$live"; dst="$ROOT/$rel"; fi
    if [[ $command == collect && ! -f $src ]]; then echo "Skip missing live file: $src"; continue; fi
    saved="$backup/$rel"
    mkdir -p -- "$(dirname -- "$saved")"
    printf '%s\t%s\n' "$rel" "$dst" >> "$backup/manifest.tsv"
    if [[ -e $dst ]]; then
        if [[ $command == deploy && $rel == system/* ]]; then sudo cp -a -- "$dst" "$saved"; else cp -a -- "$dst" "$saved"; fi
    else printf '%s\n' "$dst" >> "$backup/originally-absent.txt"; fi
    if [[ $command == deploy && $rel == system/* ]]; then
        sudo install -D -o root -g root -m "${modes[$i]}" -- "$src" "$dst"
    elif [[ $command == collect && $rel == system/* ]]; then
        mkdir -p -- "$(dirname -- "$dst")"
        temp="$(mktemp "$(dirname -- "$dst")/.collect-XXXXXXXX")"
        if ! sudo cat -- "$src" > "$temp"; then rm -f -- "$temp"; exit 1; fi
        chmod "${modes[$i]}" "$temp"; mv -- "$temp" "$dst"
    else install -D -m "${modes[$i]}" -- "$src" "$dst"; fi
done
if [[ $command == deploy ]]; then
    sudo systemctl daemon-reload
    echo "Deployment complete. Backup: $backup"
    echo "Reload Sway with Mod+Shift+c; exec startup entries take effect next login."
    echo "Restart Brave normally. Restart PipeWire separately only when convenient."
    echo "Run './sync.sh setup-timers' explicitly to configure maintenance timers."
else
    echo "Collected live files into the repository. Backup: $backup"
    echo "This was not git pull. Review git diff before committing or pushing."
    echo "The existing host FIFO implementation is not replaced or collected automatically."
fi
