"""ci.yml skips its macOS work only when every changed path is docs-only."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts" / "ci"))

from docs_only import has_code  # noqa: E402


class DocsOnlyTests(unittest.TestCase):
    def test_docs_paths_alone_are_not_code(self) -> None:
        for path in (
            "AGENTS.md",
            "README.md",
            "core-docs/images/container-failure-screen.png",
            "releases/2.0.md",
            ".claude/skills/merge-pr/SKILL.md",
            ".claude/settings.json",
            ".agents/skills/create-pr",
            ".codex/hooks.json",
            ".github/pull_request_template.md",
            "LICENSE",
            "checklists/checklistsUITests/FLAKY_TESTS.md",
        ):
            with self.subTest(path=path):
                self.assertFalse(has_code([path]))

    def test_code_paths_are_code(self) -> None:
        for path in (
            "checklists/checklists/ChecklistView.swift",
            "checklists/checklistsTests/FooTests.swift",
            "checklists/checklistsUITests/README.md",
            "Makefile",
            "scripts/build.sh",
            "scripts/translate_catalog/PROMPT_TEMPLATE.md",
            "i18n/brief.md",
            "fastlane/SETUP.md",
            ".github/workflows/ci.yml",
            "lefthook.yml",
            ".swiftlint.yml",
        ):
            with self.subTest(path=path):
                self.assertTrue(has_code([path]))

    def test_one_code_file_among_docs_is_code(self) -> None:
        self.assertTrue(has_code(["AGENTS.md", "checklists/checklists/A.swift", "README.md"]))

    def test_a_rename_out_of_the_app_folder_is_code(self) -> None:
        self.assertTrue(has_code(["checklists/checklists/NOTES.md", "core-docs/NOTES.md"]))

    def test_no_known_files_is_code(self) -> None:
        self.assertTrue(has_code([]))
        self.assertTrue(has_code(["", "  "]))


if __name__ == "__main__":
    unittest.main()
