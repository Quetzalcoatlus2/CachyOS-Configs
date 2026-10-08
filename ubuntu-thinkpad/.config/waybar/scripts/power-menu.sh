#!/bin/sh

action=$(printf '%s\n' 'Lock' 'Suspend' 'Logout' 'Reboot' 'Shutdown' | wofi --dmenu --prompt 'Power')

case "$action" in
    Lock) swaylock -f -c 000000 ;;
    Suspend) systemctl suspend ;;
    Logout) swaymsg exit ;;
    Reboot) systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
esac