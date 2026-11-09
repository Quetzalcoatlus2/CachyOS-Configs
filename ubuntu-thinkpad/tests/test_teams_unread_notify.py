import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / ".config/sway/scripts/teams-unread-notify.py"
spec = importlib.util.spec_from_file_location("teams_unread_notify", SCRIPT)
teams = importlib.util.module_from_spec(spec)
spec.loader.exec_module(teams)


class UnreadTrackerTests(unittest.TestCase):
    def setUp(self):
        self.tracker = teams.UnreadTracker(grace=30.0)

    def test_rise_after_grace_notifies_with_chat_name(self):
        self.assertIsNone(self.tracker.update(1, "Chat | Team | Microsoft Teams", 0))
        self.assertIsNone(self.tracker.update(1, "(2) Chat | Team | Microsoft Teams", 10))
        self.assertEqual(
            self.tracker.update(1, "(3) Chat | Team | Microsoft Teams", 40),
            (3, "Chat | Team"),
        )

    def test_unchanged_or_lower_count_does_not_notify(self):
        self.tracker.update(1, "(5) Chat | A | Microsoft Teams", 0)
        self.assertIsNone(self.tracker.update(1, "(5) Chat | A | Microsoft Teams", 40))
        self.assertIsNone(self.tracker.update(1, "(2) Chat | A | Microsoft Teams", 50))

    def test_new_message_after_reading_notifies_again(self):
        self.tracker.update(1, "(1) Chat | A | Microsoft Teams", 0)
        self.assertIsNone(self.tracker.update(1, "Chat | A | Microsoft Teams", 40))
        self.assertEqual(
            self.tracker.update(1, "(1) Chat | A | Microsoft Teams", 50),
            (1, "Chat | A"),
        )

    def test_matches_teams_by_xwayland_class_or_app_id(self):
        self.assertTrue(teams.is_teams({"window_properties": {"class": "teams-for-linux_teams-for-linux"}}))
        self.assertTrue(teams.is_teams({"app_id": "teams-for-linux"}))
        self.assertFalse(teams.is_teams({"window_properties": {"class": "foot"}}))


if __name__ == "__main__":
    unittest.main()
