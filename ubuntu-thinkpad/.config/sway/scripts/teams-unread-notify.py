#!/usr/bin/env python3
# Teams for Linux only sends desktop notifications for meetings. Chat messages only
# raise the unread count, which Teams writes into the window title as "(n) Chat | ...".
# This watches that title through sway, so it works whichever workspace Teams is on.
import json
import re
import subprocess
import time

TEAMS_CLASS = "teams-for-linux"
UNREAD = re.compile(r"^\((\d+)\)\s*(.*)$")
TEAMS_SUFFIX = re.compile(r"\s*\|\s*Microsoft Teams$")
# Teams loads its unread count after its window appears; that first rise is not a new message.
STARTUP_GRACE = 30.0


def is_teams(container):
    props = container.get("window_properties") or {}
    app_id = container.get("app_id") or ""
    return (props.get("class") or "").startswith(TEAMS_CLASS) or app_id.startswith(TEAMS_CLASS)


def teams_windows(node):
    if is_teams(node):
        yield node
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        yield from teams_windows(child)


class UnreadTracker:
    def __init__(self, grace=STARTUP_GRACE):
        self.grace = grace
        self.counts = {}
        self.first_seen = {}

    def forget(self, con_id):
        self.counts.pop(con_id, None)
        self.first_seen.pop(con_id, None)

    def update(self, con_id, title, now):
        """Return (count, chat) when a window's unread count rose after its startup grace."""
        match = UNREAD.match(title or "")
        count = int(match.group(1)) if match else 0
        first = self.first_seen.setdefault(con_id, now)
        previous = self.counts.get(con_id, count)
        self.counts[con_id] = count
        if count <= previous or now - first < self.grace:
            return None
        rest = match.group(2) if match else (title or "")
        return count, TEAMS_SUFFIX.sub("", rest)


def swaymsg_json(*args):
    return json.loads(subprocess.run(["swaymsg", "-t", *args], capture_output=True, text=True, check=True).stdout)


def notify(count, chat):
    subprocess.run(["notify-send", "-a", "Teams", "-t", "10000", f"Teams: {count} unread", chat], check=False)


def main():
    tracker = UnreadTracker()
    start = time.monotonic()
    for container in teams_windows(swaymsg_json("get_tree")):
        tracker.update(container["id"], container.get("name"), start)
    monitor = subprocess.Popen(
        ["swaymsg", "-r", "-m", "-t", "subscribe", '["window"]'],
        stdout=subprocess.PIPE,
        text=True,
    )
    for line in monitor.stdout:
        if not line.strip():
            continue
        event = json.loads(line)
        container = event.get("container") or {}
        if not is_teams(container):
            continue
        if event.get("change") == "close":
            tracker.forget(container.get("id"))
        elif event.get("change") in ("new", "title"):
            result = tracker.update(container.get("id"), container.get("name"), time.monotonic())
            if result:
                notify(*result)


if __name__ == "__main__":
    main()
