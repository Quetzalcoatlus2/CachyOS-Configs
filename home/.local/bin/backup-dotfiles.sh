#!/usr/bin/env bash
set -e

BACKUP_DIR="$HOME/.dotfiles"
REMOTE_REPO="git@github.com:Quetzalcoatlus2/CachyOS-Configs.git"
# ~/.dotfiles is a disposable snapshot of $HOME state; its history anchors are
# irrelevant. Snapshot commits go to the "backup" branch with --force so they
# can never clobber or be clobbered by main, which the curated repo at
# ~/CachyOS-Configs owns (home/... system/... layout).
BACKUP_REF="backup"

TARGETS=(
    ".config/waybar"
    ".config/sway"
    ".config/swaylock"
    ".config/swayidle"
    ".config/mako"
    ".config/foot"
    ".config/wofi"
    ".zshrc"
)

mkdir -p "$BACKUP_DIR"
rm -rf "$BACKUP_DIR/hypr" "$BACKUP_DIR/.config/hypr"

cd "$HOME"
for target in "${TARGETS[@]}"; do
    if [ -e "$target" ]; then
        rsync -aR --delete --exclude='.git' --exclude='*~' --exclude='*.before-autotiling-*' "$target" "$BACKUP_DIR/"
    fi
done

cd "$BACKUP_DIR"

if [ ! -d ".git" ]; then
    git init
    git branch -M "$BACKUP_REF"
    git remote add origin "$REMOTE_REPO"
else
    git remote set-url origin "$REMOTE_REPO"
fi

git add -A
if ! git diff --staged --quiet; then
    git commit -m "Backup: $(date '+%Y-%m-%d %H:%M:%S')"
    # The branch is a mirror of $HOME state; force is the correct policy here.
    git push --force origin "HEAD:refs/heads/${BACKUP_REF}"
fi
