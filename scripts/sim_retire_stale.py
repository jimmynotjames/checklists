#!/usr/bin/env python3
"""Delete a named simulator if it runs an older iOS than the newest one installed.

The sandbox and screenshot scripts reuse their per-clone simulator by name, and
resolve_sim_spec.py only picks the newest runtime when a device is first created.
Without this, a device created before an Xcode upgrade keeps running the old iOS
forever, and tests silently never see the new SDK's behavior. Deleting it lets the
caller's create path rebuild it on the newest runtime.

A device whose runtime has been uninstalled is retired too: it can no longer boot.
Matches the exact device name only, so it cannot touch another clone's devices.
Exits 0 always (callers treat this as best-effort); logs what it did to stderr.

Usage:
    python3 sim_retire_stale.py --name "iPhone 17 [a1b2c3d4]"
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys

from resolve_sim_spec import newest_ios_runtime, runtime_version

SIMCTL_TIMEOUT_SEC = 15


def simctl(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["xcrun", "simctl", *args],
        capture_output=True,
        text=True,
        timeout=SIMCTL_TIMEOUT_SEC,
    )


def stale_devices(name: str, devices: dict[str, list[dict]], runtimes: list[dict]) -> list[tuple[dict, str]]:
    """Devices named `name` that are behind the newest iOS runtime, with the reason.

    `devices` and `runtimes` are the parsed `simctl list devices -j` / `runtimes -j` bodies.
    Returns nothing when no iOS runtime is installed: there is nothing to rebuild onto.
    """
    newest = newest_ios_runtime(runtimes)
    if newest is None:
        return []
    versions = {r["identifier"]: r["version"] for r in runtimes if r.get("isAvailable")}
    found = []
    for runtime_id, runtime_devices in devices.items():
        for d in runtime_devices:
            if d.get("name") != name:
                continue
            version = versions.get(runtime_id)
            if version is None or not d.get("isAvailable", True):
                found.append((d, f"its runtime {runtime_id} is no longer installed"))
            elif runtime_version(version) < runtime_version(newest["version"]):
                found.append((d, f"it runs iOS {version}, newest installed is iOS {newest['version']}"))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    args = parser.parse_args()

    try:
        devices = json.loads(simctl("list", "devices", "-j").stdout).get("devices", {})
        runtimes = json.loads(simctl("list", "runtimes", "-j").stdout).get("runtimes", [])
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError) as e:
        print(f"sim-retire: could not list simulators ({e}); leaving devices alone", file=sys.stderr)
        return 0

    for d, reason in stale_devices(args.name, devices, runtimes):
        udid = d["udid"]
        print(f"sim-retire: replacing {args.name} ({udid}): {reason}", file=sys.stderr)
        if d.get("state") == "Booted":
            simctl("shutdown", udid)
        result = simctl("delete", udid)
        if result.returncode != 0:
            print(f"sim-retire: warning: delete failed: {result.stderr.strip()}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
