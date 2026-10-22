#!/usr/bin/env python3
# Simulink ribbon flickers after MATLAB maps a window. Toggling fullscreen on and
# off settles the layout, so each Simulink window gets that once, when it first shows up.
import json
import subprocess
import threading
import time

CYCLES = 10
START_DELAY = 3.0
STEP_DELAY = 0.1


def is_simulink(container):
    props = container.get("window_properties") or {}
    return (props.get("class") or "").startswith("MATLAB") and "Simulink" in (container.get("name") or "")


def swaymsg(*args):
    subprocess.run(["swaymsg", *args], stdout=subprocess.DEVNULL, check=False)


def simulink_ids_in(node, found):
    if is_simulink(node):
        found.add(node.get("id"))
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        simulink_ids_in(child, found)
    return found


def cycle_fullscreen(con_id):
    time.sleep(START_DELAY)
    for _ in range(CYCLES):
        swaymsg(f"[con_id={con_id}]", "fullscreen", "enable")
        time.sleep(STEP_DELAY)
        swaymsg(f"[con_id={con_id}]", "fullscreen", "disable")
        time.sleep(STEP_DELAY)


def main():
    # Windows already open at startup are left alone, so a model in use isn't toggled.
    tree = json.loads(subprocess.run(["swaymsg", "-t", "get_tree"], capture_output=True, text=True, check=True).stdout)
    handled = simulink_ids_in(tree, set())
    monitor = subprocess.Popen(
        ["swaymsg", "-r", "-m", "-t", "subscribe", '["window"]'],
        stdout=subprocess.PIPE,
        text=True,
    )
    for line in monitor.stdout:
        line = line.strip()
        if not line:
            continue
        event = json.loads(line)
        container = event.get("container") or {}
        if event.get("change") not in ("new", "title") or not is_simulink(container):
            continue
        con_id = container.get("id")
        if con_id in handled:
            continue
        handled.add(con_id)
        threading.Thread(target=cycle_fullscreen, args=(con_id,), daemon=True).start()


if __name__ == "__main__":
    main()
