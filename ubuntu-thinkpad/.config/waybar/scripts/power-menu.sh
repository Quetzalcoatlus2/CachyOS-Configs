#!/usr/bin/env bash

# Power menu opened from the 💡 button in the top bar.
# The first list is two columns under the button. Instructions opens a second list with the text
# of each action, placed under the bar at the same right edge (the first list has closed by then).
# Both lists use power-menu.css and power-menu.conf, so a second 💡 click closes whichever is open.
# power-menu.conf sets single_click=true, so one click activates. --cache-file /dev/null keeps the
# order fixed; without it wofi moves the last chosen item to the top on the next open.

MENU_STYLE="$HOME/.config/wofi/power-menu.css"
WOFI_CONF="$HOME/.config/wofi/power-menu.conf"

# Toggle: a second click closes the open list. Lists are matched by stylesheet path, so the
# $mod+d launcher (wofi --show drun) is not affected.
if pgrep -f "wofi .*power-menu\.css" >/dev/null; then
    pkill -f "wofi .*power-menu\.css"
    exit 0
fi

INSTRUCTIONS="📖 Instructions"
LOCK="🔒 Lock"
LOGOUT="🚪 Logout"
SHUTDOWN="⚡ Shutdown"
REBOOT="🔁 Reboot"
SUSPEND="🌙 Suspend"
SUSPEND_THEN_HIBERNATE="⏳ Suspend-Then-Hibernate"
HIBERNATE="💾 Hibernate"
HYBRID="🔄 Hybrid-Sleep"
CANCEL="❌ Cancel"

# Two columns of five, placed under the 💡 power button at the right end of the top bar.
# Column 1: Lock, Logout, Shutdown, Reboot, Instructions. Column 2: Suspend, Suspend-Then-Hibernate,
# Hibernate, Hybrid-Sleep, Cancel. wofi fills each row left to right, so the list is interleaved by row.
MENU=(
    "$LOCK" "$SUSPEND"
    "$LOGOUT" "$SUSPEND_THEN_HIBERNATE"
    "$SHUTDOWN" "$HIBERNATE"
    "$REBOOT" "$HYBRID"
    "$INSTRUCTIONS" "$CANCEL"
)

# Text for the Instructions list: one wofi row per line, each kept under about 100 characters.
INSTRUCTION_LINES=(
    "SESSION & TERMINATION CONTROLS"
    "🔒 Lock (swaylock)"
    "    Mechanism: swaylock PAM authentication; blanks the screen while jobs keep running."
    "    Power:     Active runtime power (~5-15 W); no battery savings or thermal cooldown."
    "    Use case:  Stepping away briefly in shared offices, client sites, or co-working spaces."
    "🚪 Logout (swaymsg exit)"
    "    Mechanism: Sway IPC exit; closes the compositor, Wayland clients, and apps."
    "    Power:     Idle at the login screen; frees all user-space RAM and GPU buffers."
    "    Use case:  Switching users, applying shell config changes, or ending the work session."
    "⚡ Shutdown (systemctl poweroff)"
    "    Mechanism: Flushes I/O queues, commits journals, unmounts cleanly, then powers off."
    "    Power:     0.0 W; power rails are cut and volatile memory is lost."
    "    Use case:  Transport, hardware servicing, electrical storms, or end-of-day power-down."
    "🔁 Reboot (systemctl reboot)"
    "    Mechanism: Stops daemons, flushes storage caches, unmounts drives, resets via UEFI."
    "    Power:     Full power cycle through BIOS/UEFI POST and systemd startup."
    "    Use case:  Applying kernel patches, rebuilding DKMS modules, or clearing driver faults."
    ""
    "POWER-SAVING & PERSISTENCE MODES"
    "🌙 Suspend (suspend-to-RAM, ACPI S3)"
    "    Mechanism: Halts userspace and cuts SoC/GPU power; DRAM stays refreshed for instant wake."
    "    Power:     About 0.5-1.2 W; resumes in under 1 s via key, mouse, or lid open."
    "    Use case:  Short breaks in the workday when a fast return to the session is needed."
    "⏳ Suspend-Then-Hibernate (systemd-suspend-then-hibernate)"
    "    Mechanism: Sleeps in RAM, then writes the RAM image to swap if the idle timer expires."
    "    Power:     About 0.8 W in RAM sleep, then 0.0 W once the image is on disk."
    "    Use case:  Overnight sleep without battery-drain risk; all workspaces are kept."
    "💾 Hibernate (suspend-to-disk, ACPI S4)"
    "    Mechanism: Writes the RAM image to /swap/swapfile, verifies it, then powers off."
    "    Power:     0.0 W; no standby drain, heat, or wear."
    "    Use case:  Multi-day storage, flights, or transport with sessions left untouched."
    "🔄 Hybrid-Sleep (systemd-hybrid-sleep)"
    "    Mechanism: Writes the RAM image to swap while staying in low-power S3 sleep."
    "    Fault:     Wakes from RAM while the battery holds; recovers from swap if it depletes."
    "    Use case:  Unattended laptops with an uncertain charge, or desktops without a UPS."
    ""
    "Press Escape or click a line to close."
)

# Measured on the eDP-1 top bar: the power button ends about 19 px from the output's right edge.
# The tray sits to the right of the button, so increase POWER_RIGHT_OFFSET if tray icons are added.
POWER_RIGHT_OFFSET=19
# A right-anchored wofi cannot be inset from the right edge (its x offset only narrows the window),
# so both lists are anchored top-left and placed by x, with their right edges at POWER_RIGHT_OFFSET.
MENU_WIDTH=360
MENU_HEIGHT=158
INSTR_WIDTH=820
INSTR_HEIGHT=$(( ${#INSTRUCTION_LINES[@]} * 24 + 8 ))
OUTPUT_WIDTH=$(swaymsg -r -t get_outputs 2>/dev/null | jq -r '[.[] | select(.focused)][0].rect.width // empty')
MENU_X=$(( ${OUTPUT_WIDTH:-1920} - POWER_RIGHT_OFFSET - MENU_WIDTH ))
INSTR_X=$(( ${OUTPUT_WIDTH:-1920} - POWER_RIGHT_OFFSET - INSTR_WIDTH ))

# Waybar reserves the top 19 px, so no vertical offset is needed to sit directly below the bar.
choice=$(printf '%s\n' "${MENU[@]}" | wofi --dmenu \
    --conf "$WOFI_CONF" \
    --cache-file /dev/null \
    --style "$MENU_STYLE" \
    --location top_left \
    --xoffset "$MENU_X" \
    --yoffset 0 \
    --columns 2 \
    --width "$MENU_WIDTH" \
    --height "$MENU_HEIGHT" \
    --hide-search \
    --hide-scroll \
    --no-custom-entry)

case "$choice" in
    "$INSTRUCTIONS")
        # Shows the text of each action directly below the bar. Nothing is run here; Escape or a
        # click on a line closes it.
        printf '%s\n' "${INSTRUCTION_LINES[@]}" | wofi --dmenu \
            --conf "$WOFI_CONF" \
            --cache-file /dev/null \
            --style "$MENU_STYLE" \
            --location top_left \
            --xoffset "$INSTR_X" \
            --yoffset 0 \
            --width "$INSTR_WIDTH" \
            --height "$INSTR_HEIGHT" \
            --hide-search \
            --hide-scroll \
            --no-custom-entry >/dev/null
        exit 0
        ;;
    "$LOCK") action="env LD_LIBRARY_PATH=$HOME/.local/opt/sway-1.12/lib $HOME/.local/opt/sway-1.12/bin/swaylock -c 000000" ;;
    "$LOGOUT") action="swaymsg exit" ;;
    "$SHUTDOWN") action="systemctl poweroff" ;;
    "$REBOOT") action="systemctl reboot" ;;
    "$SUSPEND") action="systemctl suspend" ;;
    "$SUSPEND_THEN_HIBERNATE") action="systemctl suspend-then-hibernate || notify-send -u critical 'Suspend-Then-Hibernate failed' 'Not available: no resume device configured or swap too small'" ;;
    "$HIBERNATE") action="systemctl hibernate || notify-send -u critical 'Hibernate failed' 'Not available: no resume device configured or swap too small'" ;;
    "$HYBRID") action="systemctl hybrid-sleep || notify-send -u critical 'Hybrid-Sleep failed' 'Not available: no resume device configured or swap too small'" ;;
    *) exit 0 ;;
esac

# Detached so swaylock or a slow command does not keep the bar's click handler busy.
setsid -f sh -c "$action"
