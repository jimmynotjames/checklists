#!/usr/bin/env python3
"""Print one `TEST-FAILED: <test id> <file:line> <failure text>` line per failure in a test run.

Report-only: never changes the run's outcome. The file:line comes from the result bundle, so a
flaky-test log entry never has to guess it (AGENTS.md §"Reading a test result").

Usage: python3 scripts/list_test_failures.py <path-to.xcresult>
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
PREFIX = "TEST-FAILED:"


def failures_from_tree(tree: dict, repo_root: Path = REPO_ROOT) -> list[dict]:
    """Every failure message in `xcresulttool get test-results tests` output, with its test case."""
    found: list[dict] = []

    def walk(node: dict, test_id: str | None) -> None:
        if node.get("nodeType") == "Test Case":
            test_id = node.get("nodeIdentifier") or node.get("name") or test_id
        if node.get("nodeType") == "Failure Message":
            found.append({
                "test": test_id or "?",
                "location": _location(node.get("sourceLocation"), repo_root),
                "text": " ".join((node.get("name") or "").split()),
            })
        for child in node.get("children") or []:
            walk(child, test_id)

    for root in tree.get("testNodes") or []:
        walk(root, None)
    return found


def _location(source: dict | None, repo_root: Path) -> str:
    if not source or not source.get("filePath"):
        return "?"
    path = Path(source["filePath"])
    try:
        path = path.relative_to(repo_root)
    except ValueError:
        pass
    line = source.get("lineNumber")
    return f"{path}:{line}" if line is not None else str(path)


def read_tree(bundle: str) -> dict:
    result = subprocess.run(
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", bundle],
        capture_output=True,
        check=False,
    )
    if result.returncode != 0 or not result.stdout:
        return {}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", help="Path to the run's .xcresult")
    args = parser.parse_args(argv)

    for failure in failures_from_tree(read_tree(args.bundle)):
        print(f"{PREFIX} {failure['test']} {failure['location']} {failure['text']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
