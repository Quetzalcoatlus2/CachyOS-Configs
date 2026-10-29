import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1] / ".config/waybar/scripts"


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(
            os.environ,
            PATH=f"{self.root}:/usr/bin:/bin",
            UPDATE_ALL_NO_PAUSE="1",
            UPDATE_ALL_NO_BANNER="1",
            CALLS=str(self.root / "calls"),
        )
        self.stub("pgrep", "exit 1")
        self.stub("sudo", 'printf "%s\\n" "$*" >> "$CALLS"\nexit "${SUDO_RC:-0}"')

    def stub(self, name, body):
        path = self.root / name
        path.write_text("#!/bin/sh\n" + body + "\n")
        path.chmod(0o755)

    def run_script(self, name, *args):
        return subprocess.run(
            ["bash", str(SCRIPTS / name), *args],
            env=self.env, text=True, capture_output=True,
        )

    def test_counts_and_thresholds(self):
        for count, expected in [(0, "updated"), (1, "low"), (10, "low"),
                                (11, "medium"), (35, "medium"), (36, "high")]:
            with self.subTest(count=count):
                self.stub("apt-get", f"i=0; while [ $i -lt {count} ]; do echo 'Inst pkg'; i=$((i+1)); done")
                result = self.run_script("updates.sh")
                self.assertEqual(result.returncode, 0, result.stderr)
                data = json.loads(result.stdout)
                self.assertEqual(data["class"], expected)
                self.assertEqual(data["text"], f"📦{count}")

    def test_check_failure_is_not_zero_updates(self):
        self.stub("apt-get", "echo 'E: \"bad\" <index> & unavailable' >&2\nexit 100")
        result = self.run_script("updates.sh")
        self.assertEqual(result.returncode, 0)
        data = json.loads(result.stdout)
        self.assertEqual(data["class"], "error")
        self.assertEqual(data["text"], "📦!")
        self.assertIn("&lt;index&gt;", data["tooltip"])
        self.assertIn("exit 100", data["tooltip"])

    def test_dry_run_never_uses_sudo(self):
        self.stub("apt-get", 'printf "%s\\n" "$*"')
        result = self.run_script("update-all.sh", "--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("-s upgrade", result.stdout)
        self.assertFalse((self.root / "calls").exists())

    def test_partial_source_warning_is_visible(self):
        self.stub("apt-get", "echo 'W: Unable to read /etc/apt/sources.list' >&2\necho 'Inst pkg'")
        result = self.run_script("updates.sh")
        self.assertEqual(result.returncode, 0)
        data = json.loads(result.stdout)
        self.assertEqual(data["class"], "error")
        self.assertIn("Unable to read", data["tooltip"])

    def test_refresh_failure_stops_upgrade(self):
        self.env["SUDO_RC"] = "100"
        result = self.run_script("update-all.sh")
        self.assertEqual(result.returncode, 100)
        self.assertIn("failed (exit 100)", result.stderr)
        self.assertEqual((self.root / "calls").read_text().splitlines(),
                         ["apt-get -o APT::Update::Error-Mode=any update"])

    def test_upgrade_follows_refresh(self):
        result = self.run_script("update-all.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / "calls").read_text().splitlines(),
                         ["apt-get -o APT::Update::Error-Mode=any update", "apt-get upgrade"])

    def test_bad_arguments(self):
        result = self.run_script("update-all.sh", "--dry-run", "extra")
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.root / "calls").exists())


if __name__ == "__main__":
    unittest.main()
