#!/bin/bash
set -euo pipefail
DOTFILES_DIR="${DOTFILES_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"

# Everything under these trees is tracked in the repo, and every one of them is
# wired up below. Keep the two lists in sync with `git ls-files home/ system/`.
USER_DIRS=(
    "$DOTFILES_DIR/home/.config/atuin"
    "$DOTFILES_DIR/home/.config/foot"
    "$DOTFILES_DIR/home/.config/gtk-3.0"
    "$DOTFILES_DIR/home/.config/mako"
    "$DOTFILES_DIR/home/.config/micro"
    "$DOTFILES_DIR/home/.config/micro/colorschemes"
    "$DOTFILES_DIR/home/.config/micro/syntax"
    "$DOTFILES_DIR/home/.config/pipewire/pipewire.conf.d"
    "$DOTFILES_DIR/home/.config/sway"
    "$DOTFILES_DIR/home/.config/swaylock"
    "$DOTFILES_DIR/home/.config/waybar"
    "$DOTFILES_DIR/home/.config/waybar/scripts"
)

# Corresponding paths under the live $HOME.
LIVE_USER_DIRS=(
    "$HOME/.config/atuin"
    "$HOME/.config/foot"
    "$HOME/.config/gtk-3.0"
    "$HOME/.config/mako"
    "$HOME/.config/micro"
    "$HOME/.config/micro/colorschemes"
    "$HOME/.config/micro/syntax"
    "$HOME/.config/pipewire/pipewire.conf.d"
    "$HOME/.config/sway"
    "$HOME/.config/swaylock"
    "$HOME/.config/waybar"
    "$HOME/.config/waybar/scripts"
)

# repo-relative user file  ->  path relative to $HOME
USER_FILES=(
    ".config/atuin/config.toml"
    ".config/foot/foot.ini"
    ".config/gtk-3.0/gtk.css"
    ".config/gtk-3.0/settings.ini"
    ".config/mako/config"
    ".config/micro/bindings.json"
    ".config/micro/settings.json"
    ".config/pipewire/pipewire.conf.d/99-quantum.conf"
    ".config/sway/config"
    ".config/swaylock/config"
    ".zshrc"
)

# repo-relative user directory (contents copied recursively)
USER_TREES=(
    ".config/micro/colorschemes"
    ".config/micro/syntax"
    ".config/waybar"
)

# repo path  ->  system path
SYSTEM_FILES=(
    "system/etc/systemd/zram-generator.conf:/etc/systemd/zram-generator.conf"
    "system/etc/systemd/sleep.conf.d/battery-hibernate.conf:/etc/systemd/sleep.conf.d/battery-hibernate.conf"
    "system/etc/sysctl.d/99-zz-congestion.conf:/etc/sysctl.d/99-zz-congestion.conf"
    "system/etc/tmpfiles.d/hibernate-image-size.conf:/etc/tmpfiles.d/hibernate-image-size.conf"
    "system/etc/modules-load.d/cake.conf:/etc/modules-load.d/cake.conf"
    "system/usr/local/bin/nmtui:/usr/local/bin/nmtui"
    "system/usr/local/bin/brave-browser-nightly:/usr/local/bin/brave-browser-nightly"
    "system/etc/NetworkManager/dispatcher.d/99-cake.sh:/etc/NetworkManager/dispatcher.d/99-cake.sh"
    "system/usr/lib/systemd/system-sleep/zram-hibernate.sh:/usr/lib/systemd/system-sleep/zram-hibernate.sh"
)

mkdirs() { mkdir -p "$@"; }

case "${1:-}" in
    pull)
        echo "Collecting active configs into repository..."
        mkdirs "${USER_DIRS[@]}" \
            "$DOTFILES_DIR/system/etc/systemd/sleep.conf.d" \
            "$DOTFILES_DIR/system/etc/sysctl.d" \
            "$DOTFILES_DIR/system/etc/tmpfiles.d" \
            "$DOTFILES_DIR/system/etc/modules-load.d" \
            "$DOTFILES_DIR/system/etc/NetworkManager/dispatcher.d" \
            "$DOTFILES_DIR/system/usr/lib/systemd/system-sleep" \
            "$DOTFILES_DIR/system/usr/local/bin"

        # User configuration files
        for rel in "${USER_FILES[@]}"; do
            src="${HOME}/${rel}"
            [ -f "$src" ] || { echo "  skip (missing): \$HOME/${rel}"; continue; }
            cp "$src" "$DOTFILES_DIR/home/$rel"
        done

        # User configuration trees (copied via a trailing /. so the contents
        # land in the destination rather than nesting a subdirectory)
        for rel in "${USER_TREES[@]}"; do
            src="${HOME}/${rel}"
            [ -d "$src" ] || { echo "  skip (missing): \$HOME/${rel}"; continue; }
            cp -r "$src/." "$DOTFILES_DIR/home/$rel/"
        done

        # System configuration files
        for pair in "${SYSTEM_FILES[@]}"; do
            src="/${pair#*:}"
            [ -f "$src" ] || { echo "  skip (missing): ${src}"; continue; }
            sudo cp "$src" "$DOTFILES_DIR/${pair%%:*}"
        done

        sudo chown -R "$USER:$USER" "$DOTFILES_DIR"
        echo "Done. Run 'git diff' or 'git status' to review changes."
        ;;

    deploy)
        echo "Deploying configs to system..."
        mkdirs "${LIVE_USER_DIRS[@]}"
        sudo mkdir -p /etc/systemd/sleep.conf.d /etc/sysctl.d /etc/tmpfiles.d \
            /usr/local/bin /etc/modules-load.d /etc/NetworkManager/dispatcher.d \
            /usr/lib/systemd/system-sleep

        # User configuration files
        for rel in "${USER_FILES[@]}"; do
            src="$DOTFILES_DIR/home/$rel"
            [ -f "$src" ] || { echo "  skip (missing): home/${rel}"; continue; }
            cp "$src" "${HOME}/${rel}"
        done

        # User configuration trees
        for rel in "${USER_TREES[@]}"; do
            src="$DOTFILES_DIR/home/$rel"
            [ -d "$src" ] || { echo "  skip (missing): home/${rel}"; continue; }
            cp -r "$src/." "${HOME}/${rel}/"
        done

        # Executable bits for anything in the repo that is marked 100755
        find "${HOME}/.config/waybar/scripts" -type f -exec chmod +x {} +

        # System configuration files
        for pair in "${SYSTEM_FILES[@]}"; do
            src="$DOTFILES_DIR/${pair%%:*}"
            [ -f "$src" ] || { echo "  skip (missing): ${pair%%:*}"; continue; }
            sudo cp "$src" "/${pair#*:}"
        done
        sudo chmod +x /usr/local/bin/nmtui
        sudo chmod +x /usr/local/bin/brave-browser-nightly
        sudo chmod +x /etc/NetworkManager/dispatcher.d/99-cake.sh
        sudo chmod +x /usr/lib/systemd/system-sleep/zram-hibernate.sh
        sudo systemctl enable NetworkManager-dispatcher.service

        sudo chmod +x /usr/local/bin/nmtui
        sudo systemctl daemon-reload
        sudo sysctl --system
        sudo systemd-tmpfiles --create /etc/tmpfiles.d/hibernate-image-size.conf
        echo "Deployment complete. Restart sway (Mod+Shift+c) and restart PipeWire to apply."
        ;;

    check)
        # Verify every tracked file is actually wired into this script, either
        # as an explicit entry or as a member of a copied tree.
        echo "Tracked files not referenced by sync.sh:"
        missing=0
        while read -r f; do
            managed=0
            for rel in "${USER_FILES[@]}"; do
                [ "$f" = "home/$rel" ] && managed=1 && break
            done
            if [ "$managed" -eq 0 ]; then
                for rel in "${USER_TREES[@]}"; do
                    case "$f" in "home/$rel"/*) managed=1; break ;; esac
                done
            fi
            if [ "$managed" -eq 0 ]; then
                for pair in "${SYSTEM_FILES[@]}"; do
                    [ "$f" = "${pair%%:*}" ] && managed=1 && break
                done
            fi
            [ "$managed" -eq 0 ] && { echo "  $f"; missing=1; }
        done < <(git -C "$DOTFILES_DIR" ls-files home/ system/)
        [ "$missing" -eq 0 ] && echo "  (none - all tracked files are managed)"
        ;;

    *)
        echo "Usage: $0 {pull|deploy|check}"
        exit 1
        ;;
esac
