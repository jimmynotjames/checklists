#!/usr/bin/env python3
"""Resolve device-type ID and runtime ID for a simulator name.

Outputs two lines: <device-type-id>\n<runtime-id>
Exits 0 on success, 1 on failure.

Usage:
    python3 resolve_sim_spec.py --name "iPhone 17"
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys


def simctl_json(*args: str) -> dict:
    out = subprocess.check_output(
        ["xcrun", "simctl", *args, "-j"],
        text=True,
        timeout=10,
    )
    return json.loads(out)


def newest_ios_runtime(runtimes: list[dict]) -> dict | None:
    """The highest-versioned available iOS runtime from `simctl list runtimes -j`."""
    ios = [r for r in runtimes if r.get("isAvailable") and "iOS" in r.get("name", "")]
    return max(ios, key=lambda r: runtime_version(r["version"]), default=None)


def runtime_version(version: str) -> tuple[int, ...]:
    return tuple(int(x) for x in version.split("."))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    args = parser.parse_args()
    name: str = args.name

    # -- Device type resolution --
    device_type_id: str | None = None
    try:
        types = simctl_json("list", "devicetypes").get("devicetypes", [])
        # 1. Exact name match
        for t in types:
            if t.get("name") == name:
                device_type_id = t["identifier"]
                break
        # 2. Name-prefix match (e.g. "iPhone 17" → "iPhone 17 Pro")
        if device_type_id is None:
            for t in types:
                if t.get("name", "").startswith(name):
                    device_type_id = t["identifier"]
                    break
        # 3. Family fallback (any iPhone / iPad), preferring the newest
        if device_type_id is None:
            family = name.split()[0]
            for t in reversed(types):
                if t.get("name", "").startswith(family):
                    device_type_id = t["identifier"]
                    break
    except Exception as e:
        print(f"error: could not list device types: {e}", file=sys.stderr)
        sys.exit(1)

    if device_type_id is None:
        print(f"error: no device type found for '{name}'", file=sys.stderr)
        sys.exit(1)

    # -- Runtime resolution (newest available iOS) --
    runtime_id: str | None = None
    try:
        newest = newest_ios_runtime(simctl_json("list", "runtimes").get("runtimes", []))
        if newest:
            runtime_id = newest["identifier"]
    except Exception as e:
        print(f"error: could not list runtimes: {e}", file=sys.stderr)
        sys.exit(1)

    if runtime_id is None:
        print("error: no available iOS runtime found", file=sys.stderr)
        sys.exit(1)

    print(device_type_id)
    print(runtime_id)


if __name__ == "__main__":
    main()
