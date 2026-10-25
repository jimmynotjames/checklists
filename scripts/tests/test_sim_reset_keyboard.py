"""A simulator's keyboard preferences lose only the values that hide the software keyboard."""

from __future__ import annotations

import plistlib
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from sim_reset_keyboard import prefs_path, strip_keys  # noqa: E402

PREFS = {
    "AutomaticMinimizationEnabled": False,
    "HardwareKeyboardLastSeen": 1.0,
    "KeyboardsCurrentAndNext": ["en_US@sw=QWERTY;hw=Automatic"],
}


class StripKeysTests(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "com.apple.keyboard.preferences.plist"

    def tearDown(self) -> None:
        self.dir.cleanup()

    def test_removes_both_keys_and_keeps_the_rest(self) -> None:
        self.path.write_bytes(plistlib.dumps(PREFS, fmt=plistlib.FMT_BINARY))
        self.assertEqual(strip_keys(self.path), ["AutomaticMinimizationEnabled", "HardwareKeyboardLastSeen"])
        self.assertEqual(plistlib.loads(self.path.read_bytes()), {"KeyboardsCurrentAndNext": PREFS["KeyboardsCurrentAndNext"]})

    def test_keeps_a_binary_file_binary(self) -> None:
        self.path.write_bytes(plistlib.dumps(PREFS, fmt=plistlib.FMT_BINARY))
        strip_keys(self.path)
        self.assertTrue(self.path.read_bytes().startswith(b"bplist"))

    def test_keeps_automatic_minimization_when_true(self) -> None:
        self.path.write_bytes(plistlib.dumps({"AutomaticMinimizationEnabled": True}, fmt=plistlib.FMT_BINARY))
        self.assertEqual(strip_keys(self.path), [])
        self.assertEqual(plistlib.loads(self.path.read_bytes()), {"AutomaticMinimizationEnabled": True})

    def test_dry_run_reports_without_writing(self) -> None:
        before = plistlib.dumps(PREFS, fmt=plistlib.FMT_XML)
        self.path.write_bytes(before)
        self.assertEqual(strip_keys(self.path, dry_run=True), ["AutomaticMinimizationEnabled", "HardwareKeyboardLastSeen"])
        self.assertEqual(self.path.read_bytes(), before)

    def test_clean_file_is_left_untouched(self) -> None:
        before = plistlib.dumps({"KeyboardsCurrentAndNext": []}, fmt=plistlib.FMT_BINARY)
        self.path.write_bytes(before)
        self.assertEqual(strip_keys(self.path), [])
        self.assertEqual(self.path.read_bytes(), before)

    def test_missing_file_is_nothing_to_do(self) -> None:
        self.assertEqual(strip_keys(self.path), [])
        self.assertFalse(self.path.exists())


class PrefsPathTests(unittest.TestCase):
    def test_points_into_the_device_data_directory(self) -> None:
        path = prefs_path("U1", Path("/devices"))
        self.assertEqual(path, Path("/devices/U1/data/Library/Preferences/com.apple.keyboard.preferences.plist"))


if __name__ == "__main__":
    unittest.main()
