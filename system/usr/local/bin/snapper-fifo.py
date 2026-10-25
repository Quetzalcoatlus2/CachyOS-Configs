#!/usr/bin/env python3
"""Root Snapper FIFO retention; dry-run unless --apply is supplied."""
import argparse
import csv
import fcntl
import io
import os
from pathlib import Path
import subprocess
import sys

SNAPPER = "/usr/bin/snapper"
COLUMNS = ["number", "active", "default", "pre-number", "post-number"]

def parse_rows(text):
    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames != COLUMNS:
        raise ValueError("Unexpected Snapper CSV columns; refusing cleanup")
    records = {}
    for row in reader:
        if None in row or any(row.get(k) is None for k in COLUMNS):
            raise ValueError("Malformed Snapper CSV row")
        number = int(row["number"])
        if number < 0 or number in records:
            raise ValueError("Invalid or duplicate snapshot number")
        if row["active"] not in ("yes", "no") or row["default"] not in ("yes", "no"):
            raise ValueError("Unexpected snapshot protection flags")
        links = [int(row[k]) for k in ("pre-number", "post-number") if row[k]]
        if any(n <= 0 for n in links):
            raise ValueError("Invalid snapshot pair reference")
        if number:
            records[number] = {"protected": row["active"] == "yes" or row["default"] == "yes", "links": links}
    return records

def read_records():
    result = subprocess.run(
        [SNAPPER, "--csvout", "-c", "root", "list", "--disable-used-space", "--columns", ",".join(COLUMNS)],
        check=True, text=True, stdout=subprocess.PIPE,
        env={**os.environ, "LC_ALL": "C"},
    )
    return parse_rows(result.stdout)

def plan(records, limit):
    parent = {n: n for n in records}
    def root(n):
        while parent[n] != n:
            parent[n] = parent[parent[n]]
            n = parent[n]
        return n
    for n, record in records.items():
        for other in record["links"]:
            if other in parent:
                parent[root(other)] = root(n)
    groups = {}
    for n in records:
        groups.setdefault(root(n), []).append(n)
    ordered = sorted((sorted(g) for g in groups.values()), key=lambda g: g[0])
    if any(len(g) > 2 for g in ordered):
        raise ValueError("Unexpected pair relationship; refusing cleanup")
    remaining, selected = len(records), []
    for group in ordered:
        if remaining <= limit:
            break
        if any(records[n]["protected"] for n in group):
            continue
        selected.append(group)
        remaining -= len(group)
    return selected, remaining

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Delete planned oldest snapshots")
    parser.add_argument("--limit", type=int, default=500)
    args = parser.parse_args()
    if args.limit < 1:
        parser.error("--limit must be positive")
    if os.geteuid() != 0:
        parser.error("run with sudo (also for the dry-run)")
    with open("/run/snapper-fifo.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        before = read_records()
        groups, expected = plan(before, args.limit)
        ids = [n for group in groups for n in group]
        print(f"Stored root snapshots: {len(before)}; limit: {args.limit}", flush=True)
        print("Delete oldest IDs: " + (", ".join(map(str, ids)) if ids else "none"), flush=True)
        print(f"Expected remaining: {expected}; complete pairs are retained/deleted together", flush=True)
        if not args.apply:
            print("DRY RUN: nothing deleted", flush=True)
            return
        for group in groups:
            current = read_records()
            if any(n not in current or current[n]["protected"] for n in group):
                raise RuntimeError("Snapshot state changed; stopping rather than deleting")
            linked = {other for n in group for other in current[n]["links"] if other in current}
            if not linked.issubset(set(group)):
                raise RuntimeError("Snapshot pair changed; refusing deletion")
            subprocess.run([SNAPPER, "-c", "root", "delete", *map(str, group)], check=True)
        remaining = len(read_records())
        print(f"Cleanup complete; remaining root snapshots: {remaining}", flush=True)
        if remaining > args.limit:
            raise RuntimeError("Limit not reached: protected snapshots or concurrent snapshot creation; inspect before retrying")

if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
