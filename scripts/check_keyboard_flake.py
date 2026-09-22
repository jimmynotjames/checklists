#!/usr/bin/env python3
"""Tag UI test failures caused by the simulator's software keyboard being absent.

Prints `SIM-KEYBOARD-FLAKE tests-failed` when a run failed on a keyboard key, so that the
question in issue #231 — does the keyboard machinery in `_sim_sandbox.sh` still protect
anything? — can later be answered by grepping transcripts and run logs instead of by argument.

The tests stopped tapping keyboard keys in `97e78c9` (see `XCUIElement+Keyboard.swift`), and
`check_ui_test_keyboard.py` fails the gate on any new tap, so a hit here means something got past
both and is worth investigating rather than waving through.

Deliberately precise rather than generous: a false positive would argue for keeping machinery that
may well be dead weight. Only `kAXErrorCannotComplete` against a keyboard element counts. The
edit-menu variant ("Failed to tap \"Cut\" MenuItem", seen once when nothing had been typed) is left
out — same suspected family, but the element is not a key and blaming it here would overstate.

Never fails the build: it reports on a run that has already decided its own outcome.

Usage:
  python3 scripts/check_keyboard_flake.py <path-to.xcresult>
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
