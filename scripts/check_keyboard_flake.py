#!/usr/bin/env python3
"""Print `SIM-KEYBOARD-FLAKE tests-failed` when a UI run failed with `kAXErrorCannotComplete` on a
keyboard key. Report-only: never changes the run's outcome. Why: the XCUIElement+Keyboard.swift header.

Usage: python3 scripts/check_keyboard_flake.py <path-to.xcresult>
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

TAG = "SIM-KEYBOARD-FLAKE"
ISSUE = "https://github.com/jimmynotjames/checklists/issues/231"

# The keyboard's own elements, as XCUITest names them in a failure message.
KEYBOARD_ELEMENT = re.compile(
    r"identifier: '(?:Next:|delete|done|Return|return|next)'|\bKey,",
)


def failures(bundle: str) -> list[dict]:
    result = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", bundle],
        capture_output=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout:
        return []
    try:
        return json.loads(result.stdout).get("testFailures", []) or []
    except json.JSONDecodeError:
        return []


def keyboard_failures(bundle: str) -> list[dict]:
    hits = []
    for failure in failures(bundle):
        text = failure.get("failureText") or ""
        if "kAXErrorCannotComplete" in text and KEYBOARD_ELEMENT.search(text):
            hits.append({"test": failure.get("testName", "?"), "text": text})
    return hits


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", help="Path to the run's .xcresult")
    args = parser.parse_args(argv)

    hits = keyboard_failures(args.bundle)
    if not hits:
        return 0

    print(
        f"\n{TAG} tests-failed: {len(hits)} UI test failure(s) on a software-keyboard key.",
        file=sys.stderr,
    )
    for hit in hits:
        print(f"  {hit['test']}", file=sys.stderr)
    print(
        f"The UI tests are not supposed to need the keyboard any more — see {ISSUE}.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
