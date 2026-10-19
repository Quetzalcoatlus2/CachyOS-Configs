#!/usr/bin/env bash
exec 9>/dev/shm/sway_brave_fs.lock
flock -n 9 || exit 0

swaymsg -m -t subscribe '["window"]' | jq --unbuffered -r '
  select(.change == "fullscreen_mode" and .container.fullscreen_mode == 1 and (.container.app_id // "" | test("^brave"; "i")))
  | .container.id
' | while read -r con_id; do
  sleep 0.08
  swaymsg "[con_id=${con_id}] border pixel 1; [con_id=${con_id}] border pixel 0" >/dev/null 2>&1
done
