#!/usr/bin/env python3
"""Shut down and delete every simulator whose name contains this checkout's `[slug]`.

That covers the sandbox device, its xcodebuild "Clone N of ..." leftovers, and this
checkout's Screenshots device. The slug is hashed from the checkout path, as
`_sim_sandbox.sh` derives it, so another checkout's devices are never touched.

Usage: python3 scripts/sim_clean.py
"""
from __future__ import annotations

import hashlib
import json
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


def slug_from_root(root: Path = ROOT) -> str:
    return hashlib.sha1(str(root).encode("utf-8")).hexdigest()[:8]


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


def main() -> int:
    slug = slug_from_root()
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
