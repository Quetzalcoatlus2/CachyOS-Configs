# Ubuntu ThinkPad Sway DisplayLink

Working setup: Intel laptop panel plus Eizo EV2316W through a ThinkPad Hybrid
USB-C/USB-A DisplayLink dock (DUD9011D1), on Ubuntu 22.04.

## Prerequisites

The launcher requires a separately built swayfx stack at
`$HOME/.local/opt/swayfx` (swayfx 0.6 with scenefx 0.5) on top of the private
Sway 1.12 / wlroots 0.20 prefix at `$HOME/.local/opt/sway-1.12`; it does not use
Ubuntu's Sway 1.7. The sway-1.12 prefix supplies wlroots 0.20.0 with XWayland
enabled, Wayland 1.24.0, wayland-protocols 1.47, libdrm 2.4.130, xkbcommon 1.8.0,
Pixman 0.46.4, libdisplay-info 0.4.0, libinput 1.26.2, XCB 1.17.0, and
xcb-util-wm 0.4.2 (`xcb-ewmh`, `xcb-icccm`). The swayfx build uses GNU m4 1.4.21
for xcb-util-wm. The build works around Ubuntu's older Khronos `GLES2/gl2ext.h`
with a newer header passed as an include override.
It uses the system Mesa libraries and XWayland 22.1.1. DisplayLink driver
6.4.0-22 and EVDI 1.15.1 were installed during verification.

Build artifacts, private build tools, crash dumps, and diagnostic logs are not
included here. Installing these configs alone does not build their prerequisites.

## Locking and idle

This session also requires swaylock 1.8.6 (commit
`44b82de635c3bc66b0093abd1cf8cc1c8b1b9c0f`) and swayidle 1.9.0 (commit
`a959e59c64b55dd17a974dda4c4b71dff520af3a`) installed under the same
`$HOME/.local/opt/sway-1.12` prefix. Build them against that prefix's Wayland
libraries and protocols using `PATH`, `PKG_CONFIG_PATH`, and `LD_LIBRARY_PATH`.
Ubuntu's swaylock 1.5 uses the obsolete input-inhibitor protocol, and its old
swayidle uses an idle protocol no longer supported by this compositor. Changing
lock command flags does not resolve that protocol mismatch.

Keep the system swaylock package and `/etc/pam.d/swaylock` for PAM authentication.
A PAM file installed inside the private prefix does not replace the system PAM
policy. Do not bypass authentication or protocol safety checks.

The config and Waybar power menu explicitly select the private executables and
library path. Super+Ctrl+L locks immediately; idle handling locks after 600 seconds,
powers displays off after 900 seconds, restores power on activity, and locks before
sleep. Sway's `exec` startup commands do not restart on config reload: after changing
the idle command, restart that daemon once or start a new session, avoiding duplicate
instances. The updated daemon was already started manually in the current session.

## Session

Install `.config/sway/config` and the executable `.local/bin/sway-displaylink`
under the user's home. The config also expects the existing user Waybar launcher
at `/home/ABO4198/.local/bin/waybar`.

The GDM entry at `/usr/share/wayland-sessions/sway-displaylink.desktop` is:

```ini
[Desktop Entry]
Name=Sway DisplayLink
Comment=Sway with Intel and DisplayLink DRM devices
Exec=/home/ABO4198/.local/bin/sway-displaylink
Type=Application
DesktopNames=sway
```

Keep the regular Sway session and `/usr/bin/sway` unchanged as a fallback.
Select **Sway DisplayLink** after logging out. Startup errors are appended to
`$HOME/.local/state/sway-displaylink-debug/session.log`.

The launcher resolves the Intel device before constructing the colon-delimited
DRM list and detects the connected DisplayLink DVI connector rather than assuming
a fixed EVDI card number. GLES2 renders on Intel; `--unsupported-gpu` acknowledges
Sway's DisplayLink support-policy warning. The config places the external monitor
above the laptop panel using its stable monitor identity. Move the pointer through
the laptop's top edge to reach the monitor, or the monitor's bottom edge to return.

## Ubuntu updates

The Waybar update widget checks APT's local indexes hourly without root. A failed
check displays a red error indicator and diagnostic tooltip, not zero updates.
APT warnings (including unreadable source lists) also flag an incomplete check.
Clicking opens the private foot terminal, refreshes indexes with sudo, and lets
APT show its upgrade plan and ask for confirmation. Failures remain visible in
the terminal; Waybar refreshes when the workflow exits. Reboots are reported,
not initiated. No extra service restarts, package removal or cache cleanup are
requested (package maintainer scripts may still restart services normally).
The interactive Zsh `update` function uses the same workflow.

Run `bash ~/.config/waybar/scripts/update-all.sh --dry-run` for a read-only
preview using existing indexes. Private source builds, Snap and Flatpak are not
covered. The CachyOS Paru/AUR, firmware-pruning and bootloader settings are not
deployed on Ubuntu.

Portable preferences from the latest CachyOS update are adapted here: GTK4's
black theme, foot as the XFCE terminal, and native Wayland launch for Code
Insiders. Existing Ubuntu MIME defaults, Pavucontrol window dimensions, custom
Thunar action, OBS capture setup, and Waybar layout are retained rather than
overwritten by personal-machine values. Fish, Paru, Shelly and OpenCode settings
are not deployed because their CachyOS-specific packages/workflows are absent
from this Ubuntu setup.

## Display shortcuts

`Mod` is the Super/Windows key. Up always targets the external monitor; Down
always targets the laptop, even when that display is already focused.

| Shortcut | Action |
| --- | --- |
| Ctrl+Up / Ctrl+Down | Focus monitor / laptop |
| Ctrl+Shift+Up / Ctrl+Shift+Down | Move focused window or container to monitor / laptop |
| Mod+Ctrl+Shift+Up / Mod+Ctrl+Shift+Down | Move current workspace to monitor / laptop |
| Mod+1 through Mod+0 | Switch to workspace 1 through 10 |
| Mod+Shift+1 through Mod+Shift+0 | Move focused window to workspace 1 through 10 |
| Mod+arrow | Focus a neighboring window |
| Mod+Shift+arrow | Move a window within the layout |

Each display shows its own workspace. Workspace numbers are shared across the
session: selecting a workspace already visible on another display focuses it
there. Moving a workspace transfers all its windows together. If a parent
container is selected, the window-move shortcut moves that entire container.
These global Ctrl+arrow bindings override application shortcuts using the same
keys. Reload the configuration with Mod+Shift+C after changing it.