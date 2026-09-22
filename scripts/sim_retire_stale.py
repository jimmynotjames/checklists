#!/usr/bin/env python3
"""Delete a named simulator unless it runs the newest iOS the selected Xcode can target.

The sandbox and screenshot scripts reuse their per-clone simulator by name, and
resolve_sim_spec.py only picks the runtime when a device is first created. Without
this, a device created before an Xcode upgrade keeps running the old iOS forever, and
tests silently never see the new SDK's behavior. Deleting it lets the caller's create
path rebuild it on the right runtime. The same applies in reverse after switching back
from a beta Xcode.

A device whose runtime has been uninstalled is retired too: it can no longer boot. One
whose runtime is listed but unavailable is left alone, since runtimes can be briefly
unmounted after an update. Matches the exact device name only, so it cannot touch
another clone's devices. Exits 0 always (callers run under `set -e` and treat this as
best-effort); logs what it did to stderr.

Usage:
    python3 sim_retire_stale.py --name "iPhone 17 [a1b2c3d4]"
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys

from resolve_sim_spec import newest_ios_runtime, runtime_version, selected_sdk_version

SIMCTL_TIMEOUT_SEC = 15


def simctl(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["xcrun", "simctl", *args],
        capture_output=True,
        text=True,
        timeout=SIMCTL_TIMEOUT_SEC,
    )


def stale_devices(
    name: str,
    devices: dict[str, list[dict]],
    runtimes: list[dict],
    sdk_version: str | None = None,
) -> list[tuple[dict, str]]:
    """Devices named `name` that are not on the target iOS runtime, with the reason.

    `devices` and `runtimes` are the parsed `simctl list devices -j` / `runtimes -j` bodies.
    Returns nothing when no target runtime is installed: there is nothing to rebuild onto.
    """
    target = newest_ios_runtime(runtimes, sdk_version)
    if target is None:
        return []
    by_id = {r["identifier"]: r for r in runtimes}
    found = []
    for runtime_id, runtime_devices in devices.items():
        for d in runtime_devices:
            if d.get("name") != name:
                continue
            runtime = by_id.get(runtime_id)
            if runtime is None:
                found.append((d, f"its runtime {runtime_id} is no longer installed"))
            elif not runtime.get("isAvailable"):
                continue
            elif runtime_version(runtime["version"]) != runtime_version(target["version"]):
                found.append((d, f"it runs iOS {runtime['version']}, target is iOS {target['version']}"))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    args = parser.parse_args()

    try:
        devices = json.loads(simctl("list", "devices", "-j").stdout).get("devices", {})
        runtimes = json.loads(simctl("list", "runtimes", "-j").stdout).get("runtimes", [])
        stale = stale_devices(args.name, devices, runtimes, selected_sdk_version())
    except Exception as e:  # noqa: BLE001 — best-effort: never fail the caller's run
        print(f"sim-retire: could not check simulators ({e}); leaving devices alone", file=sys.stderr)
        return 0

    for d, reason in stale:
        udid = d["udid"]
        print(f"sim-retire: replacing {args.name} ({udid}): {reason}", file=sys.stderr)
        try:
            if d.get("state") == "Booted":
                simctl("shutdown", udid)
            result = simctl("delete", udid)
        except subprocess.TimeoutExpired as e:
            print(f"sim-retire: warning: {e}", file=sys.stderr)
            continue
        if result.returncode != 0:
            print(f"sim-retire: warning: delete failed: {result.stderr.strip()}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
