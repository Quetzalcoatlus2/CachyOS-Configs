#!/usr/bin/env bash

# Toggle behavior: terminate if already running
if pgrep -x swaynag >/dev/null; then
    pkill -x swaynag
    exit 0
fi

DETAILS="
─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 SESSION & TERMINATION CONTROLS                                                                                                  │ POWER-SAVING & PERSISTENCE MODES
─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 1. 🔒 LOCK (swaylock)                                                                                                           │ 5. 🌙 SUSPEND (Suspend-to-RAM / ACPI S3/s2idle)
    • Mechanism : Invokes swaylock PAM authentication; blanks Wayland surfaces while background compute and audio jobs run.      │    • Mechanism : Halts userspace execution, cuts power to SoC/GPU cores, and maintains DRAM self-refresh for instant wake.
    • Power Draw: Active runtime power (~5W - 15W); SoC clocks dynamically adjust; zero battery savings or thermal cooldown.     │    • Power Draw: Ultra-low quiescent drain (~0.5W - 1.2W); instantaneous resume (<1s) via keyboard press, mouse, or lid open.
    • Use Case  : Stepping away briefly in shared office spaces, client environments, or public co-working environments.         │    • Use Case  : Short interruptions throughout the workday when rapid return to an active multi-window workflow is needed.
                                                                                                                                 │
 2. 🚪 LOGOUT (swaymsg exit)                                                                                                     │ 6. ⏳ SUSPEND-THEN-HIBERNATE (systemd-suspend-then-hibernate)
    • Mechanism : Signals Sway IPC socket to terminate compositor; shuts down graphical clients, Wayland protocols, and apps.    │    • Mechanism : Enters RAM sleep immediately; automatically commits complete RAM image to swap storage if idle timer expires.
    • Power Draw: Active idle state at login display manager; frees all user-space physical RAM allocations and GPU buffers.     │    • Power Draw: Draws ~0.8W during initial RAM sleep phase, dropping to absolute 0.0W once written to swap partition on disk.
    • Use Case  : Switching user profiles, applying desktop shell configuration changes, or concluding the daily work session.   │    • Use Case  : Overnight laptop sleep without battery drain risk while retaining the exact state of all open workspaces.
                                                                                                                                 │
 3. 🔌 SHUTDOWN (systemctl poweroff)                                                                                             │ 7. 💾 HIBERNATE (Suspend-to-Disk / ACPI S4)
    • Mechanism : Flushes kernel I/O queues, commits Btrfs journals, unmounts subvolumes cleanly, and commands ACPI S5/G3.       │    • Mechanism : Serializes physical memory image into /swap/swapfile, verifies disk image integrity, and powers off hardware.
    • Power Draw: Absolute 0.0W hardware cutoff; completely isolates motherboard power rails and flushes volatile memory.        │    • Power Draw: Absolute 0.0W draw; preserves battery indefinitely with zero parasitic drain, standby heat, or wear.
    • Use Case  : Packing laptop in transit bags, hardware servicing, electrical storm safety, or end-of-day system powerdown.   │    • Use Case  : Multi-day storage, long-distance flights, or transport where exact application sessions must remain untouched.
                                                                                                                                 │
 4. 🔁 REBOOT (systemctl reboot)                                                                                                 │ 8. 🔄 HYBRID-SLEEP (systemd-hybrid-sleep)
    • Mechanism : Gracefully stops system daemons, flushes NVMe storage caches, unmounts drives, and executes UEFI reset vector. │    • Mechanism : Writes RAM image to swap storage while simultaneously maintaining DRAM refresh in low-power S3 sleep mode.
    • Power Draw: Full continuous power cycle passing directly through motherboard BIOS/UEFI POST and systemd initialization.    │    • Fault Tol : Instant wake from RAM if battery holds; automatically recovers cleanly from swap if battery fully depletes.
    • Use Case  : Applying Linux kernel patches, rebuilding DKMS kernel modules, or recovering from deep driver runtime faults.  │    • Use Case  : Leaving laptops unattended with uncertain remaining charge, or running desktop workstations without UPS units.
─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"

INSTRUCTIONS="📖 Instructions"
LOCK="🔒 Lock"
LOGOUT="🚪 Logout"
SHUTDOWN="⏻ Shutdown"
REBOOT="🔁 Reboot"
SUSPEND="🌙 Suspend"
SUSPEND_THEN_HIBERNATE="⏳ Suspend-Then-Hibernate"
HIBERNATE="💾 Hibernate"
HYBRID="🔄 Hybrid-Sleep"
CANCEL="✖ Cancel"

# Six groups spread across the bar with equal gaps: Instructions | Lock Logout |
# Shutdown Reboot | Suspend Suspend-Then-Hibernate | Hibernate Hybrid-Sleep | Cancel.
# Spacers are buttons in the bar colour, sized with Pango (swaynag's font) for the focused output.
LAYOUT=$(python3 - "$INSTRUCTIONS" "$LOCK" "$LOGOUT" "$SHUTDOWN" "$REBOOT" "$SUSPEND" \
    "$SUSPEND_THEN_HIBERNATE" "$HIBERNATE" "$HYBRID" "$CANCEL" <<'PY'
import json, subprocess, sys
import gi
gi.require_version('Pango', '1.0')
gi.require_version('PangoCairo', '1.0')
from gi.repository import Pango, PangoCairo

outputs = json.loads(subprocess.check_output(['swaymsg', '-t', 'get_outputs']))
width = next(o['rect']['width'] for o in outputs if o['focused'])
ctx = PangoCairo.FontMap.get_default().create_context()
# swaynag draws each glyph advance rounded to whole pixels; measuring the same way keeps widths exact.
ctx.set_round_glyph_positions(True)
font = Pango.FontDescription.from_string('monospace 9')

def text_width(markup):
    layout = Pango.Layout.new(ctx)
    layout.set_font_description(font)
    layout.set_markup(markup, -1)
    return layout.get_pixel_size()[0]

buttons = sum(text_width(t) for t in sys.argv[1:])
best = None
for gap in (14, 13, 15, 12, 16):
    for n in range(1, 200):
        # 15 items with 14 gaps. swaynag draws each button 1px narrower, so Instructions
        # lands at x=0 when the right margin equals this value.
        margin = width - buttons - 5 * text_width(' ' * n) + 15 - 14 * gap
        if margin < 8:
            break
        key = (margin - 8, abs(gap - 14))
        if best is None or key < best[0]:
            best = (key, n, gap, margin)
print(*best[1:]) if best else print(1, 14, 8)
PY
)
read -r SPACER_LEN GAP MARGIN <<<"${LAYOUT:-1 14 8}"
SPACER=$(printf '%*s' "$SPACER_LEN" '')

# Zero border/padding keeps the bar at minimum height. swaynag requires a message, so it
# is left empty: a title would be drawn at the left edge on top of Instructions.
printf '%s\n' "$DETAILS" | exec swaynag \
    --edge top \
    --layer bottom \
    --font "monospace 9" \
    --background 000000 \
    --border 222222 \
    --border-bottom 222222 \
    --border-bottom-size 0 \
    --text ffffff \
    --button-background 000000 \
    --button-text ffffff \
    --button-border-size 0 \
    --button-padding 0 \
    --button-gap "$GAP" \
    --button-dismiss-gap 0 \
    --button-margin-right "$MARGIN" \
    --message-padding 0 \
    --details-background 000000 \
    --details-border-size 1 \
    -m "" \
    -L "$INSTRUCTIONS" \
    -l \
    -s "$CANCEL" \
    -Z "$SPACER" true \
    -Z "$HYBRID" "systemctl hybrid-sleep || notify-send -u critical 'Hybrid-Sleep failed' 'Not available: no resume device configured or swap too small'" \
    -Z "$HIBERNATE" "systemctl hibernate || notify-send -u critical 'Hibernate failed' 'Not available: no resume device configured or swap too small'" \
    -Z "$SPACER" true \
    -Z "$SUSPEND_THEN_HIBERNATE" "systemctl suspend-then-hibernate || notify-send -u critical 'Suspend-Then-Hibernate failed' 'Not available: no resume device configured or swap too small'" \
    -Z "$SUSPEND" "systemctl suspend" \
    -Z "$SPACER" true \
    -Z "$REBOOT" "systemctl reboot" \
    -Z "$SHUTDOWN" "systemctl poweroff" \
    -Z "$SPACER" true \
    -Z "$LOGOUT" "swaymsg exit" \
    -Z "$LOCK" "env LD_LIBRARY_PATH=$HOME/.local/opt/sway-1.12/lib $HOME/.local/opt/sway-1.12/bin/swaylock -c 000000" \
    -Z "$SPACER" true
