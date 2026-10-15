# Ubuntu ThinkPad Sway DisplayLink

Working setup: Intel laptop panel plus Eizo EV2316W through a ThinkPad Hybrid
USB-C/USB-A DisplayLink dock (DUD9011D1), on Ubuntu 22.04.

## Prerequisites

The launcher requires a separately built Sway stack at
`$HOME/.local/opt/sway-1.12`; it does not use Ubuntu's Sway 1.7.
The working build uses Sway 1.12, wlroots 0.20.0 with XWayland enabled,
Wayland 1.24.0, wayland-protocols 1.47, libdrm 2.4.130, xkbcommon 1.8.0,
Pixman 0.46.4, libdisplay-info 0.4.0, libinput 1.26.2, and XCB 1.17.0.
It uses the system Mesa libraries and XWayland 22.1.1. DisplayLink driver
6.4.0-22 and EVDI 1.15.1 were installed during verification.

Build artifacts, private build tools, crash dumps, and diagnostic logs are not
included here. Installing these configs alone does not build their prerequisites.

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