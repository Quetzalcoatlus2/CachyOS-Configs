#!/bin/bash
set -euo pipefail
DOTFILES_DIR="$HOME/dotfiles"

case "${1:-}" in
    pull)
        echo "Collecting active configs into repository..."
        cp ~/.config/foot/foot.ini "$DOTFILES_DIR/home/.config/foot/"
        cp ~/.config/waybar/config.jsonc "$DOTFILES_DIR/home/.config/waybar/"
        cp ~/.zshrc "$DOTFILES_DIR/home/"
        
        sudo cp /etc/systemd/zram-generator.conf "$DOTFILES_DIR/system/etc/systemd/"
        sudo cp /etc/systemd/sleep.conf.d/battery-hibernate.conf "$DOTFILES_DIR/system/etc/systemd/sleep.conf.d/"
        sudo cp /usr/local/bin/nmtui "$DOTFILES_DIR/system/usr/local/bin/"
        
        sudo chown -R "$USER:$USER" "$DOTFILES_DIR"
        echo "Done. Run 'git diff' to review changes."
        ;;
    deploy)
        echo "Deploying configs to system..."
        cp "$DOTFILES_DIR/home/.config/foot/foot.ini" ~/.config/foot/
        cp "$DOTFILES_DIR/home/.config/waybar/config.jsonc" ~/.config/waybar/
        cp "$DOTFILES_DIR/home/.zshrc" ~/
        
        sudo cp "$DOTFILES_DIR/system/etc/systemd/zram-generator.conf" /etc/systemd/
        sudo cp "$DOTFILES_DIR/system/etc/systemd/sleep.conf.d/battery-hibernate.conf" /etc/systemd/sleep.conf.d/
        sudo cp "$DOTFILES_DIR/system/usr/local/bin/nmtui" /usr/local/bin/
        
        sudo chmod +x /usr/local/bin/nmtui
        sudo systemctl daemon-reload
        echo "Deployment complete."
        ;;
    *)
        echo "Usage: $0 {pull|deploy}"
        exit 1
        ;;
esac
