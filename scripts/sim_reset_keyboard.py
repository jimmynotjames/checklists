#!/usr/bin/env python3
"""Remove the keyboard preferences that can keep a simulator's software keyboard off screen.

A booted device whose `com.apple.keyboard.preferences.plist` held `AutomaticMinimizationEnabled =
false` showed no software keyboard while a field had focus, run after run, while XCUITest still
found a keyboard element. A shutdown that removed the key brought the keyboard back; a fresh boot
with `false` planted showed it too, and iOS rewrote the key as `true` on its own. So `false` on disk
marks a bad keyboard state rather than causing it, and the reboot is the cure: `_sim_sandbox.sh`
reboots a booted device that carries it, and this removes it so it doesn't trigger again. `true` is
harmless and left alone. `HardwareKeyboardLastSeen`, the other trace a hardware keyboard leaves, is
removed whenever present. What writes `false` is unknown; the host's `ConnectHardwareKeyboard` is
off.

Edit only a shut-down device: a booted one's cfprefsd holds the values in memory and writes them
back. Parallel-testing clones are copied from the device each run, so they inherit the cleaned
file.

Prints each key it removes, or with `--dry-run` would remove, one per line. Always exits 0
(best-effort under `set -e`).

Usage: python3 sim_reset_keyboard.py --udid <UDID> [--dry-run]
"""
from __future__ import annotations

import argparse
import plistlib
import sys
from pathlib import Path

# Each key, with whether its value is one that hides the keyboard.
HARMFUL = {
    "AutomaticMinimizationEnabled": lambda value: value is False,
    "HardwareKeyboardLastSeen": lambda value: True,
}
DEVICES_DIR = Path.home() / "Library" / "Developer" / "CoreSimulator" / "Devices"


def prefs_path(udid: str, devices_dir: Path = DEVICES_DIR) -> Path:
    return devices_dir / udid / "data" / "Library" / "Preferences" / "com.apple.keyboard.preferences.plist"


def strip_keys(path: Path, dry_run: bool = False) -> list[str]:
    """The `HARMFUL` keys in the plist at `path`, removed unless `dry_run`. Keeps the file's format."""
    if not path.is_file():
        return []
    raw = path.read_bytes()
    prefs = plistlib.loads(raw)
    found = [k for k, harmful in HARMFUL.items() if k in prefs and harmful(prefs[k])]
    if found and not dry_run:
        for k in found:
            del prefs[k]
        fmt = plistlib.FMT_BINARY if raw.startswith(b"bplist") else plistlib.FMT_XML
        path.write_bytes(plistlib.dumps(prefs, fmt=fmt))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        for key in strip_keys(prefs_path(args.udid), args.dry_run):
            print(key)
    except Exception as e:  # noqa: BLE001 — best-effort: never fail the caller's run
        print(f"sim-reset-keyboard: could not read keyboard preferences ({e})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
