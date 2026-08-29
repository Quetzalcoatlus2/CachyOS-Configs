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
 3. ⏻ SHUTDOWN (systemctl poweroff)                                                                                              │ 7. 💾 HIBERNATE (Suspend-to-Disk / ACPI S4)
    • Mechanism : Flushes kernel I/O queues, commits Btrfs journals, unmounts subvolumes cleanly, and commands ACPI S5/G3.       │    • Mechanism : Serializes physical memory image into /swap/swapfile, verifies disk image integrity, and powers off hardware.
    • Power Draw: Absolute 0.0W hardware cutoff; completely isolates motherboard power rails and flushes volatile memory.        │    • Power Draw: Absolute 0.0W draw; preserves battery indefinitely with zero parasitic drain, standby heat, or wear.
    • Use Case  : Packing laptop in transit bags, hardware servicing, electrical storm safety, or end-of-day system powerdown.   │    • Use Case  : Multi-day storage, long-distance flights, or transport where exact application sessions must remain untouched.
                                                                                                                                 │
 4. 🔁 REBOOT (systemctl reboot)                                                                                                 │ 8. 🔄 HYBRID-SLEEP (systemd-hybrid-sleep)
    • Mechanism : Gracefully stops system daemons, flushes NVMe storage caches, unmounts drives, and executes UEFI reset vector. │    • Mechanism : Writes RAM image to swap storage while simultaneously maintaining DRAM refresh in low-power S3 sleep mode.
    • Power Draw: Full continuous power cycle passing directly through motherboard BIOS/UEFI POST and systemd initialization.    │    • Fault Tol : Instant wake from RAM if battery holds; automatically recovers cleanly from swap if battery fully depletes.
    • Use Case  : Applying Linux kernel patches, rebuilding DKMS kernel modules, or recovering from deep driver runtime faults.  │    • Use Case  : Leaving laptops unattended with uncertain remaining charge, or running desktop workstations without UPS units.
─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"

printf '%s\n' "$DETAILS" | exec swaynag \
    --edge top \
    --layer top \
    --font "monospace 9" \
    --background 000000 \
    --border 222222 \
    --border-bottom 222222 \
    --border-bottom-size 1 \
    --text ffffff \
    --button-background 000000 \
    --button-text ffffff \
    --button-border-size 1 \
    --details-background 000000 \
    --details-border-size 1 \
    -m "Power Management Options" \
    -L "📖 Instructions" \
    -l \
    -s "✖ Cancel" \
    -Z "🔄 Hybrid-Sleep" "systemctl hybrid-sleep" \
    -Z "💾 Hibernate" "systemctl hibernate" \
    -Z "⏳ Suspend-Then-Hibernate" "systemctl suspend-then-hibernate" \
    -Z "🌙 Suspend" "systemctl suspend" \
    -Z "🔁 Reboot" "systemctl reboot" \
    -Z "⏻ Shutdown" "systemctl poweroff" \
    -Z "🚪 Logout" "swaymsg exit" \
    -Z "🔒 Lock" "swaylock -c 000000"
