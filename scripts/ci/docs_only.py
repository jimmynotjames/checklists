#!/usr/bin/env python3
"""Decide whether a PR's changed files are all docs, so ci.yml can skip its macOS work.

Reads one changed path per line on stdin (a rename contributes both its old and new path) and
prints `code=false` only when every path is docs-only, else `code=true`. An empty list prints
`code=true`: nothing known about the change means the tests run.

Conservative by design: a path is docs only when it matches below and is not under the app folder.
Swift, the Makefile, workflows, scripts (prompt templates in scripts/ feed tested code), i18n/
(the localization data those templates and checks read) and fastlane all count as code.
"""

from __future__ import annotations

import sys

DOCS_DIRS = (".agents/", ".claude/", ".codex/", "core-docs/", "releases/")
DOCS_ROOT_FILES = ("LICENSE", "NOTICE")
# Docs inside a target folder, kept out of the target by the project's membershipExceptions.
DOCS_IN_TARGET_FOLDERS = ("checklists/checklistsUITests/FLAKY_TESTS.md",)
# Markdown here is input to code, not documentation (i18n/brief.md fills the prompt templates).
CODE_MARKDOWN_DIRS = ("scripts/", "fastlane/", "i18n/")


def is_docs(path: str) -> bool:
    path = path.strip().strip('"')
    if path in DOCS_IN_TARGET_FOLDERS:
        return True
    if not path or path.startswith("checklists"):  # the app, its tests and UI tests
        return False
    if path.startswith(DOCS_DIRS) or path in DOCS_ROOT_FILES:
        return True
    return path.endswith(".md") and not path.startswith(CODE_MARKDOWN_DIRS)


def has_code(paths: list[str]) -> bool:
    paths = [p for p in paths if p.strip()]
    return not paths or not all(is_docs(p) for p in paths)


def main() -> int:
    code = has_code(sys.stdin.read().splitlines())
    print(f"code={'true' if code else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
