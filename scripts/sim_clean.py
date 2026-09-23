#!/usr/bin/env python3
"""Shut down and delete every simulator whose name contains this checkout's `[slug]`.

That covers the sandbox device, its xcodebuild "Clone N of ..." leftovers, and this
checkout's Screenshots device. The slug comes from the device named in the UDID file,
else from the checkout path, as `_sim_sandbox.sh` derives it. Never touches another
checkout's devices.

Usage: python3 scripts/sim_clean.py --slug-from-file .build/sim/device.udid
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

SIMCTL_TIMEOUT_SEC = 15
ROOT = Path(__file__).resolve().parents[1]


def simctl(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["xcrun", "simctl", *args],
        capture_output=True,
        text=True,
        timeout=SIMCTL_TIMEOUT_SEC,
    )


def slug_from_udid(udid: str) -> str | None:
    """Look up a booted/shutdown device by UDID and extract the slug from its name."""
    try:
        out = simctl("list", "devices", "-j").stdout
        data = json.loads(out)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return None
    for runtime_devices in data.get("devices", {}).values():
        for d in runtime_devices:
            if d.get("udid") == udid:
                m = re.search(r"\[([a-f0-9]{8})\]", d.get("name", ""))
                if m:
                    return m.group(1)
    return None


def find_matching_devices(slug: str) -> list[dict]:
    """Return all devices (any runtime, any state) whose name contains [slug]."""
    needle = f"[{slug}]"
    try:
        out = simctl("list", "devices", "-j").stdout
        data = json.loads(out)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return []
    found = []
    for runtime_devices in data.get("devices", {}).values():
        for d in runtime_devices:
            if needle in d.get("name", ""):
                found.append(d)
    return found


def slug_from_root(root: Path = ROOT) -> str:
    return hashlib.sha1(str(root).encode("utf-8")).hexdigest()[:8]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--slug-from-file", required=True, help="Path to file containing the device UDID")
    args = parser.parse_args()

    udid_path = Path(args.slug_from_file)
    udid = udid_path.read_text().strip() if udid_path.exists() else ""
    slug = (slug_from_udid(udid) if udid else None) or slug_from_root()

    devices = find_matching_devices(slug)
    if not devices:
        print(f"sim-clean: no devices found with slug [{slug}]")
        return 0

    print(f"sim-clean: found {len(devices)} device(s) with slug [{slug}]")
    for d in devices:
        name = d.get("name", "?")
        udid = d.get("udid", "?")
        state = d.get("state", "?")
        print(f"  - {name} ({udid}) [{state}]")
        if state == "Booted":
            simctl("shutdown", udid)
        result = simctl("delete", udid)
        if result.returncode != 0:
            print(f"    warning: delete failed: {result.stderr.strip()}", file=sys.stderr)

    print(f"sim-clean: deleted {len(devices)} device(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
