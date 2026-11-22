#!/usr/bin/env bash
# Sway can leave a thin strip around a browser that enters fullscreen before its
# geometry settles. Toggling the border twice after the event forces a redraw.
# Applies to Brave (CachyOS) and Edge (Ubuntu); WebKit/Chromium PWAs included.
exec 9>/dev/shm/sway_browser_fs.lock
flock -n 9 || exit 0

swaymsg -m -t subscribe '["window"]' | jq --unbuffered -r '
  select(.change == "fullscreen_mode" and .container.fullscreen_mode == 1)
  | .container
  | select((((.app_id // "") + " " + (.window_properties.class // "")) | test("brave|microsoft-edge|msedge"; "i")))
  | .id
' | while read -r con_id; do
  sleep 0.08
  swaymsg "[con_id=${con_id}] border pixel 1; [con_id=${con_id}] border pixel 0" >/dev/null 2>&1
done
