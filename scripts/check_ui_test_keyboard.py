#!/usr/bin/env python3
"""Fail when a UI test taps a software-keyboard key.

Tapping `app.keys["delete"]` or `app.buttons["Next:"]` requires the key to be rendered and
hit-testable, so those taps fail with `kAXErrorCannotComplete` on any simulator that has a
hardware keyboard connected. Six tests failed that way for as long as anyone had been running
them, and every one of the taps came from the Xcode UI recorder rather than a deliberate choice.

`XCUIElement.pressReturnKey()` / `pressDeleteKey(_:)` drive the same app code through `typeText`,
which synthesizes an event against whatever holds keyboard focus and never touches the keyboard's
accessibility elements. This check exists because the recorder will happily generate the old form
again the next time someone records a test.

The app's own controls are addressed as `buttons["Done"]` / `buttons["Delete"]` (capital), so only
the lowercase keyboard spellings are matched here.

Usage:
  python3 scripts/check_ui_test_keyboard.py            # exit 1 on any hit
  python3 scripts/check_ui_test_keyboard.py --json     # machine-readable
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
UI_TESTS_DIR = REPO_ROOT / "checklists" / "checklistsUITests"

# Vendored fastlane; its `typeKey` use is macOS-only screenshot plumbing, not ours to change.
EXCLUDED = {"SnapshotHelper.swift"}

PATTERNS = [
    (re.compile(r"\.keys\["), 'app.keys["…"]'),
    (re.compile(r'\.buttons\["(?:Next:|done|Return)"\]'), 'buttons["Next:"|"done"|"Return"]'),
]

FIX = (
    "Use XCUIElement.pressReturnKey() or .pressDeleteKey(_:) instead "
    "(checklists/checklistsUITests/XCUIElement+Keyboard.swift). Prefer calling them on the field "
    "rather than on `app`, so the test still fails loudly when the field never took focus."
)


def find_hits() -> list[dict]:
    hits = []
    for path in sorted(UI_TESTS_DIR.rglob("*.swift")):
        if path.name in EXCLUDED:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            # Doc comments name the old form to explain why it is gone; they are not call sites.
            if line.lstrip().startswith("//"):
                continue
            for pattern, label in PATTERNS:
                if pattern.search(line):
                    hits.append(
                        {
                            "file": str(path.relative_to(REPO_ROOT)),
                            "line": number,
                            "match": label,
                            "text": line.strip(),
                        }
                    )
                    break
    return hits


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--json", action="store_true", help="Emit hits as JSON.")
    args = parser.parse_args(argv)

    hits = find_hits()

    if args.json:
        print(json.dumps(hits, ensure_ascii=False, indent=2))
        return 1 if hits else 0

    if hits:
        print(
            f"check_ui_test_keyboard: {len(hits)} software-keyboard tap(s) — these fail whenever "
            f"the simulator has a hardware keyboard connected:",
            file=sys.stderr,
        )
        for hit in hits:
            print(f"  {hit['file']}:{hit['line']}  {hit['text']}", file=sys.stderr)
        print(f"\nFix: {FIX}", file=sys.stderr)
        return 1

    print("check_ui_test_keyboard: no UI test taps a software-keyboard key.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
