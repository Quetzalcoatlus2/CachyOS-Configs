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

## Shell and editor

The zsh config explicitly adds `$HOME/.local/bin` to `PATH` before running
fastfetch or initializing Atuin, so terminals do not depend on inheriting that
path from another shell.
Ctrl+R searches Atuin history in both vi insert and command modes. Open a new
terminal or run `source ~/.zshrc` after installing the updated config.

Micro uses the terminal clipboard, the monokai-black theme, comment shortcuts,
and Ctrl+Home/End navigation. The custom conf syntax also recognizes files under
`/etc/default/`. Root's Micro configuration is separate and was not readable during
this sync; these user settings do not prove that `sudo micro` has the same colors.
Prefer `sudoedit` with `EDITOR=micro` to edit privileged files using the user editor.
Shell/editor histories, Micro backups, and Atuin databases are not part of this sync.

## Notifications

The Sway config starts Mako and batsignal from `$HOME/.local/bin`. The verified
Mako version is Ubuntu's mako-notifier 1.6-2; its `mako` binary and `makoctl` helper
were extracted from the Ubuntu package into that directory. `makoctl` needs busctl
and jq. Batsignal 1.8.0 was built from commit
`77e34ce13d639c5e51e5c3ea5403a50f7a1e64e3` against libnotify and installed there.
These executables are separate prerequisites, not included in this repository.
Sounds use canberra-gtk-play and the freedesktop sound theme.

Normal popups last 15 seconds. Recognized Teams app names and critical alerts
remain until dismissed; Teams and critical alerts also play a sound. Popups use
the overlay layer so fullscreen applications do not hide them. Battery notices
remain visible too: batsignal warns at 25% and 20%, and reports charging to 90%.
Its danger command is disabled; this does not add automatic sleep actions.

- Super+N or left-click the bar's bell: recall the most recently closed alert.
- Super+Shift+N or right-click the bell: dismiss all visible alerts.
- Middle-click the bell: choose an action on the newest alert, when available.
- Left-click a popup: invoke its default action; right-click: dismiss it.

The bell counts active notifications, not unread Teams messages. Mako retains up
to 100 closed notifications in memory; history is lost when Mako exits or the
session ends. Desktop delivery, sticky rules, and recall were verified with test
notifications, not a real incoming Teams message. Enable native/desktop banners
and sound in Teams, check its Do Not Disturb settings, and allow notifications in
the browser if using web Teams. The daemon cannot recover messages the app never
sent. Notification content may be visible to people looking at an unlocked screen.

## Desktop Ports

The Ubuntu bar includes MPRIS media controls, a clickable scratchpad indicator,
and the corrected Simulink window matcher. Apt update badges use low (1-10),
medium (11-35), and high (36+) severity styles without replacing apt with Arch
package commands. Existing Ubuntu memory/disk/network modules are preserved.
The tracked swaylock theme matches the black/white/red live theme.

Micro retains the terminal clipboard and adds INI/conf and JSONC/JSON mappings.
Foot 1.11 rejects `scrollback-home` and `scrollback-end`, so F1/F2 retain the
compatible page-scroll behavior rather than copying unsupported newer actions.
Personal AMD paths, zram hooks, newer systemd options, and interface-specific
network tuning are deliberately not copied.

## Hibernation

Suspend-then-hibernate successfully restored the session in the user's manual test
on 2026-10-15, after increasing the swap logical volume to 32 GiB and enabling
hibernation permission for the active local user. Both logind capability checks
then returned `yes`. Direct hibernation was not separately verified in this sync.

Ubuntu's vendor policy disables hibernation by default. The local override used at
`/etc/polkit-1/localauthority/50-local.d/90-enable-hibernate.pkla` is:

```ini
[Allow hibernation for active local user]
Identity=unix-user:ABO4198
Action=org.freedesktop.login1.hibernate
ResultAny=no
ResultInactive=no
ResultActive=yes
```

This is machine-specific administrator configuration, not deployed by copying the
user config directory. Preserve the vendor policy and other users' session and
inhibitor protections. A runtime resume device of `0:0` alone is not proof that
hibernation is unavailable; permission checks and an actual restore test matter.

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