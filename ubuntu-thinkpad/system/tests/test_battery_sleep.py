import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import MagicMock, call, patch


SOURCE = Path(__file__).resolve().parents[1] / "usr/local/libexec/battery-suspend-then-hibernate.py"
SPEC = importlib.util.spec_from_file_location("battery_sleep", SOURCE)
sleep = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sleep)


class BatterySleepTests(unittest.TestCase):
    def setUp(self):
        power = patch.object(sleep, "on_external_power", return_value=False)
        power.start()
        self.addCleanup(power.stop)

    def test_threshold_and_charging(self):
        for capacity, status, expected in [
            (100, "Discharging", False), (11, "Discharging", False),
            (10, "Discharging", True), (0, "Discharging", True),
            (5, "Charging", False), (5, "Full", False),
            (5, "Not charging", False),
        ]:
            with self.subTest(capacity=capacity, status=status):
                self.assertEqual(sleep.should_hibernate([(capacity, status)]), expected)

    def test_check_intervals(self):
        self.assertEqual(sleep.check_interval([(100, "Discharging")]), 900)
        self.assertEqual(sleep.check_interval([(20, "Discharging")]), 300)

    def test_multiple_batteries(self):
        self.assertTrue(sleep.should_hibernate([(90, "Discharging"), (9, "Discharging")]))

    def test_sysfs_read_and_invalid_data(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            battery = directory / "BAT0"
            battery.mkdir()
            for name, value in {"type": "Battery", "capacity": "62", "status": "Discharging"}.items():
                (battery / name).write_text(value)
            self.assertEqual(sleep.read_batteries(directory), [(62, "Discharging")])
            (battery / "capacity").write_text("101")
            with self.assertRaises(ValueError):
                sleep.read_batteries(directory)
            (battery / "capacity").write_text("10")
            (battery / "status").write_text("Unknown")
            with self.assertRaises(ValueError):
                sleep.read_batteries(directory)

    def test_missing_battery(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaises(ValueError):
                sleep.read_batteries(Path(temporary))

    def test_manual_wake_does_not_resuspend(self):
        alarm = MagicMock()
        alarm.expired.return_value = False
        with patch.object(sleep, "WakeAlarm", return_value=alarm), \
                patch.object(sleep, "read_batteries", return_value=[(62, "Discharging")]), \
                patch.object(sleep, "system_sleep") as operation:
            sleep.run()
        operation.assert_called_once_with("suspend")
        alarm.close.assert_called_once()

    def test_scheduled_checks_then_hibernate(self):
        alarm = MagicMock()
        alarm.expired.return_value = True
        readings = [[(100, "Discharging")], [(19, "Discharging")], [(10, "Discharging")]]
        with patch.object(sleep, "WakeAlarm", return_value=alarm), \
                patch.object(sleep, "read_batteries", side_effect=readings), \
                patch.object(sleep, "system_sleep") as operation:
            sleep.run()
        self.assertEqual(operation.call_args_list, [call("suspend"), call("suspend"), call("hibernate")])
        self.assertEqual(alarm.arm.call_args_list, [call(900), call(300)])

    def test_initial_critical_battery_hibernates_without_suspending(self):
        alarm = MagicMock()
        with patch.object(sleep, "WakeAlarm", return_value=alarm), \
                patch.object(sleep, "read_batteries", return_value=[(10, "Discharging")]), \
                patch.object(sleep, "system_sleep") as operation:
            sleep.run()
        operation.assert_called_once_with("hibernate")
        alarm.arm.assert_not_called()

    def test_charging_at_low_capacity_does_not_hibernate(self):
        alarm = MagicMock()
        alarm.expired.return_value = False
        with patch.object(sleep, "WakeAlarm", return_value=alarm), \
                patch.object(sleep, "read_batteries", return_value=[(5, "Charging")]), \
                patch.object(sleep, "system_sleep") as operation:
            sleep.run()
        operation.assert_called_once_with("suspend")

    def test_external_power_prevents_hibernation(self):
        alarm = MagicMock()
        alarm.expired.return_value = False
        with patch.object(sleep, "WakeAlarm", return_value=alarm), \
                patch.object(sleep, "read_batteries", return_value=[(5, "Discharging")]), \
                patch.object(sleep, "on_external_power", return_value=True), \
                patch.object(sleep, "system_sleep") as operation:
            sleep.run()
        operation.assert_called_once_with("suspend")

    def test_sleep_failure_is_not_retried(self):
        alarm = MagicMock()
        failure = sleep.subprocess.CalledProcessError(1, sleep.SYSTEMD_SLEEP)
        with patch.object(sleep, "WakeAlarm", return_value=alarm), \
                patch.object(sleep, "read_batteries", return_value=[(62, "Discharging")]), \
                patch.object(sleep, "system_sleep", side_effect=failure) as operation:
            with self.assertRaises(sleep.subprocess.CalledProcessError):
                sleep.run()
        operation.assert_called_once_with("suspend")
        alarm.close.assert_called_once()

    def test_alarm_failure_never_suspends(self):
        alarm = MagicMock()
        alarm.arm.side_effect = OSError("alarm unavailable")
        with patch.object(sleep, "WakeAlarm", return_value=alarm), \
                patch.object(sleep, "read_batteries", return_value=[(62, "Discharging")]), \
                patch.object(sleep, "system_sleep") as operation:
            with self.assertRaises(OSError):
                sleep.run()
        operation.assert_not_called()
        alarm.close.assert_called_once()

    def test_no_sleep_if_battery_data_fails(self):
        with patch.object(sleep, "WakeAlarm"), \
                patch.object(sleep, "read_batteries", side_effect=OSError("unreadable")), \
                patch.object(sleep, "system_sleep") as operation:
            with self.assertRaises(OSError):
                sleep.run()
        operation.assert_not_called()


if __name__ == "__main__":
    unittest.main()