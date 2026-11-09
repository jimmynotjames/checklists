"""A `/ci ...` PR comment maps to the ci.yml inputs it names, and nothing else starts a run."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts" / "ci"))

from ci_command import Command, parse  # noqa: E402

EVERYTHING = "lint,secrets,large-files,i18n,build"


class ParseTests(unittest.TestCase):
    def test_bare_command_runs_the_default_gates_and_build(self) -> None:
        self.assertEqual(parse("/ci"), Command("run", only="", tests="none"))

    def test_single_gate(self) -> None:
        for gate in ("lint", "secrets", "large-files", "i18n"):
            with self.subTest(gate=gate):
                self.assertEqual(parse(f"/ci {gate}"), Command("run", only=gate))

    def test_gates_names_all_four_without_build(self) -> None:
        self.assertEqual(parse("/ci gates"), Command("run", only="lint,secrets,large-files,i18n"))

    def test_build_alone(self) -> None:
        self.assertEqual(parse("/ci build"), Command("run", only="build"))

    def test_unit_runs_only_the_build_job_with_unit_tests(self) -> None:
        self.assertEqual(parse("/ci unit"), Command("run", only="build", tests="unit"))

    def test_ui_runs_only_the_build_job_with_ui_tests(self) -> None:
        self.assertEqual(parse("/ci ui"), Command("run", only="build", tests="ui"))

    def test_all_runs_everything_with_ui_tests(self) -> None:
        self.assertEqual(parse("/ci all"), Command("run", only=EVERYTHING, tests="ui"))

    def test_words_combine_in_job_order(self) -> None:
        self.assertEqual(parse("/ci build i18n lint"), Command("run", only="lint,i18n,build"))
        self.assertEqual(
            parse("/ci gates unit"), Command("run", only=EVERYTHING, tests="unit")
        )

    def test_the_higher_test_level_wins(self) -> None:
        self.assertEqual(parse("/ci ui unit").tests, "ui")
        self.assertEqual(parse("/ci unit ui").tests, "ui")

    def test_case_commas_and_spacing_are_forgiven(self) -> None:
        self.assertEqual(parse("  /CI  Lint,I18N  "), Command("run", only="lint,i18n"))

    def test_only_the_first_line_counts(self) -> None:
        self.assertEqual(parse("/ci lint\nbuild please, and ui"), Command("run", only="lint"))

    def test_help(self) -> None:
        self.assertEqual(parse("/ci help"), Command("help"))
        self.assertEqual(parse("/ci lint help"), Command("help"))

    def test_unknown_words_are_an_error_and_start_nothing(self) -> None:
        self.assertEqual(parse("/ci lint tests xyz"), Command("error", error="tests xyz"))

    def test_other_comments_are_ignored(self) -> None:
        for body in ("/cix", "/ci-lint", "please /ci", "", "  \n", "LGTM\n/ci"):
            with self.subTest(body=body):
                self.assertEqual(parse(body).action, "ignore")


if __name__ == "__main__":
    unittest.main()
