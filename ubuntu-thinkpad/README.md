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
to the right of the laptop panel using its stable monitor identity.