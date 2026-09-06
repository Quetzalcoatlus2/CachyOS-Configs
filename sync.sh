#!/bin/bash
set -euo pipefail
DOTFILES_DIR="$HOME/dotfiles"

case "${1:-}" in
    pull)
        echo "Collecting active configs into repository..."
        mkdir -p "$DOTFILES_DIR/home/.config/sway" "$DOTFILES_DIR/home/.config/swaylock" "$DOTFILES_DIR/home/.config/waybar" "$DOTFILES_DIR/home/.config/foot"
        
        cp ~/.config/foot/foot.ini "$DOTFILES_DIR/home/.config/foot/"
        cp ~/.config/sway/config "$DOTFILES_DIR/home/.config/sway/"
        cp ~/.config/swaylock/config "$DOTFILES_DIR/home/.config/swaylock/"
        cp -r ~/.config/waybar/* "$DOTFILES_DIR/home/.config/waybar/"
        cp ~/.zshrc "$DOTFILES_DIR/home/"
        
        sudo cp /etc/systemd/zram-generator.conf "$DOTFILES_DIR/system/etc/systemd/"
        sudo cp /etc/systemd/sleep.conf.d/battery-hibernate.conf "$DOTFILES_DIR/system/etc/systemd/sleep.conf.d/"
        sudo cp /usr/local/bin/nmtui "$DOTFILES_DIR/system/usr/local/bin/"
        
        sudo chown -R "$USER:$USER" "$DOTFILES_DIR"
        echo "Done. Run 'git diff' to review changes."
        ;;
    deploy)
        echo "Deploying configs to system..."
        mkdir -p ~/.config/sway ~/.config/swaylock ~/.config/waybar ~/.config/foot
        
        cp "$DOTFILES_DIR/home/.config/foot/foot.ini" ~/.config/foot/
        cp "$DOTFILES_DIR/home/.config/sway/config" ~/.config/sway/
        cp "$DOTFILES_DIR/home/.config/swaylock/config" ~/.config/swaylock/
        cp -r "$DOTFILES_DIR/home/.config/waybar/"* ~/.config/waybar/
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
