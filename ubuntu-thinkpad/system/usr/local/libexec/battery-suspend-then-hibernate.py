#!/usr/bin/python3

import argparse
import ctypes
import logging
import os
from contextlib import closing
from pathlib import Path
import subprocess


THRESHOLD = 10
CLOCK_BOOTTIME_ALARM = 9
POWER_SUPPLY = Path("/sys/class/power_supply")
SYSTEMD_SLEEP = "/lib/systemd/systemd-sleep"


class Timespec(ctypes.Structure):
    _fields_ = [("seconds", ctypes.c_long), ("nanoseconds", ctypes.c_long)]


class Itimerspec(ctypes.Structure):
    _fields_ = [("interval", Timespec), ("value", Timespec)]


class WakeAlarm:
    def __init__(self):
        self.libc = ctypes.CDLL(None, use_errno=True)
        self.libc.timerfd_create.argtypes = [ctypes.c_int, ctypes.c_int]
        self.libc.timerfd_create.restype = ctypes.c_int
        self.libc.timerfd_settime.argtypes = [
            ctypes.c_int, ctypes.c_int, ctypes.POINTER(Itimerspec),
            ctypes.POINTER(Itimerspec),
        ]
        self.libc.timerfd_settime.restype = ctypes.c_int
        self.fd = self.libc.timerfd_create(CLOCK_BOOTTIME_ALARM, os.O_CLOEXEC | os.O_NONBLOCK)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "Cannot create battery wake alarm")

    def arm(self, seconds):
        setting = Itimerspec(Timespec(0, 0), Timespec(seconds, 0))
        if self.libc.timerfd_settime(self.fd, 0, ctypes.byref(setting), None) < 0:
            raise OSError(ctypes.get_errno(), "Cannot arm battery wake alarm")

    def expired(self):
        try:
            return len(os.read(self.fd, 8)) == 8
        except BlockingIOError:
            return False

    def close(self):
        os.close(self.fd)


def read_batteries(directory=POWER_SUPPLY):
    batteries = []
    for device in sorted(directory.iterdir()):
        if (device / "type").read_text().strip() != "Battery":
            continue
        if (device / "present").exists() and (device / "present").read_text().strip() == "0":
            continue
        capacity = int((device / "capacity").read_text().strip())
        status = (device / "status").read_text().strip()
        if not 0 <= capacity <= 100:
            raise ValueError("Battery capacity is outside 0-100%")
        if status not in {"Charging", "Discharging", "Not charging", "Full"}:
            raise ValueError("Battery charging state is unknown")
        batteries.append((capacity, status))
    if not batteries:
        raise ValueError("No readable battery found")
    return batteries


def on_external_power(directory=POWER_SUPPLY):
    for device in directory.iterdir():
        if (device / "type").read_text().strip() == "Battery":
            continue
        online = device / "online"
        if online.exists() and online.read_text().strip() == "1":
            return True
    return False


def should_hibernate(batteries):
    return any(capacity <= THRESHOLD and status == "Discharging"
               for capacity, status in batteries)


def check_interval(batteries):
    return 300 if min(capacity for capacity, _ in batteries) <= 20 else 900


def system_sleep(action):
    subprocess.run([SYSTEMD_SLEEP, action], check=True)


def run():
    with closing(WakeAlarm()) as alarm:
        while True:
            batteries = read_batteries()
            logging.info("Battery readings: %s", batteries)
            if should_hibernate(batteries) and not on_external_power():
                logging.info("Discharging battery at or below %s%%; hibernating", THRESHOLD)
                system_sleep("hibernate")
                return
            interval = check_interval(batteries)
            alarm.arm(interval)
            logging.info("Suspending; battery check in %s seconds", interval)
            system_sleep("suspend")
            if not alarm.expired():
                logging.info("Manual or other early wake; leaving the session awake")
                return
            logging.info("Scheduled wake; checking battery again")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true",
                        help="Read battery policy without arming alarms or sleeping")
    options = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    try:
        if options.check:
            batteries = read_batteries()
            external_power = on_external_power()
            print(f"batteries={batteries}; external_power={external_power}; threshold={THRESHOLD}%; "
                f"hibernate={should_hibernate(batteries) and not external_power}; "
                  f"check_interval={check_interval(batteries)}s")
            return 0
        if os.geteuid() != 0:
            parser.error("Sleep operation requires root; use --check for a safe preview")
        run()
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        logging.error("Battery sleep operation stopped: %s", error)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())