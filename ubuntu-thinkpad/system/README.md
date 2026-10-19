# Battery-Aware Suspend Then Hibernate (Ubuntu 22.04)

This optional override replaces only the systemd 249 fixed-delay implementation
behind `systemctl suspend-then-hibernate`. Plain suspend and hibernate are unchanged.
It uses the existing sleep target, logind authorization/inhibitors, and systemd-sleep
hooks. The power menu needs no command change.

## Behavior

- Hibernate when a discharging battery is at or below 10%, unless external power
  is online. Starting the operation already at this threshold hibernates immediately.
- Otherwise suspend, using a CLOCK_BOOTTIME_ALARM timerfd to schedule a battery check.
- Check every 15 minutes above 20%, and every 5 minutes at 20% or below.
- A wake before the timer expires is treated as manual/other wake: cancel the alarm
  and remain awake, without checking for hibernation or re-suspending.
- On scheduled wake, recheck power and either hibernate or suspend again.
- Unknown/unreadable battery data, alarm failure, or sleep failure stops the operation
  with an error rather than guessing or repeatedly forcing sleep.

This periodically wakes the machine briefly and consumes some battery. It cannot
promise an exact 10% transition: charge can fall between checks. A manual wake at
the exact timer deadline can be indistinguishable from the scheduled wake. A timer
wakeup is not a user unlock; the existing screen lock remains in force.

## Verify Without Sleeping

From this directory:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
python3 usr/local/libexec/battery-suspend-then-hibernate.py --check
```

Tests mock every sleep operation. `--check` reads battery data only and never arms
an alarm, suspends, or hibernates. Actual alarm wake, lid/manual wake, and restore
behavior must be tested on this laptop after installation; passing unit tests
does not establish hardware reliability. Do not rely on it unattended until tested.

## Install

Administrator installation is required. Do not install while a sleep operation is
in progress. Review any existing service overrides first:

```sh
cd "$HOME/cachyos-ref/ubuntu-thinkpad/system"
systemctl cat systemd-suspend-then-hibernate.service
sudo install -D -o root -g root -m 0644 \
  usr/local/libexec/battery-suspend-then-hibernate.py \
  /usr/local/libexec/battery-suspend-then-hibernate.py
sudo install -D -o root -g root -m 0644 \
  etc/systemd/system/systemd-suspend-then-hibernate.service.d/10-battery-threshold.conf \
  /etc/systemd/system/systemd-suspend-then-hibernate.service.d/10-battery-threshold.conf
sudo systemctl daemon-reload
systemctl cat systemd-suspend-then-hibernate.service
python3 /usr/local/libexec/battery-suspend-then-hibernate.py --check
```

The effective service should now run Python with the installed helper, instead
of `systemd-sleep suspend-then-hibernate`. No enable command or reboot is required.
Do not copy the newer personal-laptop sleep options to systemd 249.

Save work, then first test an ordinary early wake with
`systemctl suspend-then-hibernate`. It should stay awake after manually waking it.
Next supervise at least one scheduled wake and re-suspend. Check logs with:

```sh
sudo journalctl -u systemd-suspend-then-hibernate.service -b
```

Logs distinguish scheduled checks from manual wake and show battery decisions.
Direct hibernation must already restore this laptop's session reliably. Do not
discharge the battery to exhaustion as a test or lower the reserve to force a test.

## Roll Back

After waking normally and ensuring no sleep operation is in progress:

```sh
sudo rm /etc/systemd/system/systemd-suspend-then-hibernate.service.d/10-battery-threshold.conf
sudo systemctl daemon-reload
```

That restores the vendor implementation, including its fixed delay. The unused
root-owned helper can then be removed separately. Do not use `systemctl revert`,
which could delete unrelated administrator overrides.