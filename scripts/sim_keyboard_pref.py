#!/usr/bin/env python3
"""Read and write a simulator's ConnectHardwareKeyboard preference.

Both operations go through `defaults` (i.e. cfprefsd), never through the plist file.
Simulator.app owns this preference and reaches it through the same daemon, and the daemon's
cache can differ from what is on disk — so a reader that opens the file directly and a writer
that goes through the daemon can disagree indefinitely.

`defaults write DevicePreferences -dict-add <udid> '{ ... }'` replaces the device's *entire*
sub-dictionary, discarding its window geometry, tint and external-display keys. Exporting the
domain, setting the one leaf and importing it back preserves the siblings with their original
types. It is the same whole-domain read-modify-write that `-dict-add` performs, so it races
with Simulator.app no more than `-dict-add` would.

Usage:
  python3 scripts/sim_keyboard_pref.py --check   <udid>   # exit 0 when the hardware keyboard is off
  python3 scripts/sim_keyboard_pref.py --disable <udid>   # turn the hardware keyboard off
"""

from __future__ import annotations

import argparse
import plistlib
import subprocess
import sys

DOMAIN = "com.apple.iphonesimulator"
KEY = "ConnectHardwareKeyboard"


def _export() -> dict:
    result = subprocess.run(
        ["defaults", "export", DOMAIN, "-"], capture_output=True, check=False
    )
    if result.returncode != 0 or not result.stdout:
        return {}
    try:
        return plistlib.loads(result.stdout)
    except Exception:
        return {}


def _import(domain_plist: dict) -> None:
    subprocess.run(
        ["defaults", "import", DOMAIN, "-"],
        input=plistlib.dumps(domain_plist),
        check=True,
    )


def is_off(udid: str) -> bool:
    """True when this device's hardware keyboard is disabled (so the software one shows).

    Absent counts as off: a freshly created device has no entry and boots with the software
    keyboard. Both `False` and the string "0" count: `defaults ... -dict-add` writes the string
    form, and entries Simulator.app has touched hold a real boolean.
    """
    value = _export().get("DevicePreferences", {}).get(udid, {}).get(KEY)
    return value in (None, False, 0, "0")


def disable(udid: str) -> None:
    domain_plist = _export()
    devices = domain_plist.setdefault("DevicePreferences", {})
    devices.setdefault(udid, {})[KEY] = False
    _import(domain_plist)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check", metavar="UDID")
    group.add_argument("--disable", metavar="UDID")
    args = parser.parse_args(argv)

    if args.check:
        return 0 if is_off(args.check) else 1
    disable(args.disable)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
