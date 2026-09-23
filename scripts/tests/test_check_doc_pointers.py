"""Each check_doc_pointers check must fire on the drift it exists for, and stay quiet otherwise."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import check_doc_pointers as checker  # noqa: E402

HEADINGS = {"consent", "per-event properties", "lint policy", "launch and consent ordering"}


class HeadingMatchTests(unittest.TestCase):
    def test_bare_pointer_resolves_to_longest_matching_heading(self) -> None:
        ok, target, _ = checker.match_heading("Per-event properties in the same change", HEADINGS)
        self.assertTrue(ok)
        self.assertEqual(target, "Per-event properties")

    def test_trailing_punctuation_is_ignored(self) -> None:
        self.assertTrue(checker.match_heading("Launch and consent ordering).", HEADINGS)[0])

    def test_quoted_pointer_must_match_exactly(self) -> None:
        self.assertTrue(checker.match_heading('"Lint policy" says', HEADINGS)[0])
        self.assertFalse(checker.match_heading('"Lint rules"', HEADINGS)[0])

    def test_renamed_heading_is_dangling(self) -> None:
        self.assertFalse(checker.match_heading("Toggle-off behaviour", HEADINGS)[0])

    def test_heading_markup_is_normalized(self) -> None:
        self.assertEqual(checker.normalize_heading(" `Build hygiene`: "), "build hygiene")


class DocResolutionTests(unittest.TestCase):
    FILES = ["AGENTS.md", "core-docs/analytics-spec.md", ".claude/skills/create-pr/reference/review-and-gate.md",
             "fastlane/SETUP.md", "scripts/a/README.md", "scripts/b/README.md"]

    def test_basename_resolves(self) -> None:
        self.assertEqual(checker.resolve_doc("analytics-spec.md", self.FILES), "core-docs/analytics-spec.md")

    def test_relative_path_resolves(self) -> None:
        self.assertEqual(checker.resolve_doc("reference/review-and-gate.md", self.FILES),
                         ".claude/skills/create-pr/reference/review-and-gate.md")

    def test_ambiguous_or_missing_doc_is_none(self) -> None:
        self.assertIsNone(checker.resolve_doc("README.md", self.FILES))
        self.assertIsNone(checker.resolve_doc("gone-spec.md", self.FILES))


class SymbolShapeTests(unittest.TestCase):
    def test_code_symbols_are_recognized(self) -> None:
        for raw in ("ToastPresenter", "resize(in:)", "Checklist.dragItems()", "isVoiceOverRunning"):
            self.assertIsNotNone(checker.SYMBOL_SHAPE.match(raw), raw)

    def test_event_names_and_constants_are_not_symbols(self) -> None:
        self.assertFalse(checker.looks_like_code_symbol("app_opened"))
        self.assertFalse(checker.looks_like_code_symbol("ARCHS"))
        self.assertFalse(checker.looks_like_code_symbol("phone"))


class HistoryPatternTests(unittest.TestCase):
    def flagged(self, text: str) -> bool:
        return any(p.search(text) for p, _ in checker.HISTORY_PATTERNS)

    def test_history_markers_are_flagged(self) -> None:
        for text in ("// This was formerly a sheet.", "/// Kept since #133.", "once #218 lands, the screen",
                     "an earlier draft exempted it", "the title used to be cleared", "the clock was tried first"):
            self.assertTrue(self.flagged(text), text)

    def test_current_state_prose_is_not_flagged(self) -> None:
        for text in ("/// The id is used to look the checklist up.", "/// No longer on disk after a reset.",
                     "/// Tracked in #219.", "/// Restores the previously selected tab.",
                     "/// Retries if the save was tried and failed."):
            self.assertFalse(self.flagged(text), text)


class PointerScanTests(unittest.TestCase):
    """Scans a scratch doc and a scratch source file with the real pointer scanner."""

    DOC = "# Spec\n\n## Event catalog\n\n## Property catalog\n\n### What gates a merge\n"

    def errors_for(self, source: str) -> list[str]:
        scratch = REPO_ROOT / "tmp" / "doc-pointer-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        (scratch / "scratch-spec.md").write_text(self.DOC, encoding="utf-8")
        (scratch / "Sample.swift").write_text(source, encoding="utf-8")
        rel = "tmp/doc-pointer-tests/"
        errors = checker.check_pointers([rel + "scratch-spec.md", rel + "Sample.swift"])
        return [e["check"] for e in errors if e["file"].endswith("Sample.swift")]

    def test_chained_pointers_are_each_checked(self) -> None:
        self.assertEqual(self.errors_for("// scratch-spec.md §Event catalog / §Property catalog\n"), [])
        self.assertEqual(self.errors_for("// scratch-spec.md §Event catalog / §Nope\n"), ["dangling-pointer"])

    def test_quoted_pointer_can_wrap_over_three_lines(self) -> None:
        self.assertEqual(self.errors_for('/// See scratch-spec.md §"What\n/// gates\n/// a merge".\n'), [])

    def test_escaped_quotes_in_a_string_literal_resolve(self) -> None:
        self.assertEqual(self.errors_for('print("see scratch-spec.md §\\"Event catalog\\"")\n'), [])

    def test_relative_path_resolves(self) -> None:
        self.assertEqual(self.errors_for("// ../scratch-spec.md §Event catalog\n"), [])

    def test_numbered_and_unknown_pointers_are_reported(self) -> None:
        self.assertEqual(self.errors_for("// scratch-spec.md §4.2\n"), ["numbered-pointer"])
        self.assertEqual(self.errors_for("// gone-spec.md §Event catalog\n"), ["unknown-doc"])


class CorpusTests(unittest.TestCase):
    def test_swift_comments_do_not_count_as_code(self) -> None:
        text = "let a = 1 // keepsOnlyInComment\n/* alsoOnlyInComment */\nlet url = \"https://x\"\n"
        stripped = checker.SWIFT_LINE_COMMENT.sub(" ", checker.SWIFT_BLOCK_COMMENT.sub(" ", text))
        self.assertNotIn("keepsOnlyInComment", stripped)
        self.assertNotIn("alsoOnlyInComment", stripped)
        self.assertIn("https://x", stripped)


class RepoTreeTests(unittest.TestCase):
    def test_tree_is_clean(self) -> None:
        files = checker.tracked_files()
        errors = checker.check_pointers(files) + checker.check_symbols(files)
        self.assertEqual(errors, [], "\n".join(f"{e['file']}:{e['line']}: {e['message']}" for e in errors))


if __name__ == "__main__":
    unittest.main()
