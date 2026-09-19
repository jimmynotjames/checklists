"""The screenshot seeds must be derivable from the catalog, and stay that way."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "scripts"))
sys.path.insert(0, str(REPO_ROOT / "scripts" / "screenshot_content"))
sys.path.insert(0, str(REPO_ROOT / "scripts" / "translate_catalog"))

import generate_seeds as seeds  # noqa: E402


def _catalog(entries: dict[str, dict[str, str]]) -> dict:
    """Build a catalog fixture: {key: {language: value}}."""
    return {
        "strings": {
            key: {
                "localizations": {
                    language: {"stringUnit": {"state": "translated", "value": value}}
                    for language, value in by_language.items()
                }
            }
            for key, by_language in entries.items()
        }
    }


SOURCE = {
    "schemaVersion": 1,
    "locale": "en-US",
    "primaryLocale": "en_US",
    "checklists": [
        {
            "id": "C4EC1157-0000-4000-A000-000000000001",
            "name": "Morning Routine",
            "items": [
                {"name": "START COFFEE MAKER", "isChecked": True},
                {"name": "Breakfast", "notes": "Something light.", "isChecked": False},
            ],
        }
    ],
}

CATALOG = _catalog(
    {
        "sample.morningRoutine.name": {"en": "Morning Routine", "hi": "सुबह का रूटीन"},
        "sample.morningRoutine.item1": {"en": "START COFFEE MAKER", "hi": "सबसे पहले चाय"},
        "sample.morningRoutine.item2": {"en": "Breakfast", "hi": "नाश्ता"},
        "sample.morningRoutine.item2.notes": {"en": "Something light.", "hi": "कुछ हल्का।"},
    }
)


class BuildSeedTests(unittest.TestCase):
    def _build(self, catalog: dict = CATALOG, source: dict = SOURCE) -> dict:
        index = seeds.load_english_index(catalog)
        return seeds.build_seed(source, index, catalog, "hi", "hi", "hi_IN")

    def test_words_are_localized_and_structure_is_copied(self) -> None:
        seed = self._build()
        self.assertEqual(seed["locale"], "hi")
        self.assertEqual(seed["primaryLocale"], "hi_IN")
        checklist = seed["checklists"][0]
        self.assertEqual(checklist["id"], SOURCE["checklists"][0]["id"])
        self.assertEqual(checklist["name"], "सुबह का रूटीन")
        self.assertEqual([item["isChecked"] for item in checklist["items"]], [True, False])
        self.assertEqual(checklist["items"][1]["notes"], "कुछ हल्का।")

    def test_transcreation_is_carried_through_rather_than_translated_literally(self) -> None:
        # The Hindi morning routine opens with tea, not a coffee maker. Joining on
        # the English value is what lets a seed diverge this far and still resolve.
        self.assertEqual(self._build()["checklists"][0]["items"][0]["name"], "सबसे पहले चाय")

    def test_notes_absent_in_the_source_stay_absent(self) -> None:
        self.assertNotIn("notes", self._build()["checklists"][0]["items"][0])

    def test_missing_translation_fails_loudly(self) -> None:
        catalog = _catalog(
            {
                "sample.morningRoutine.name": {"en": "Morning Routine"},
                "sample.morningRoutine.item1": {"en": "START COFFEE MAKER", "hi": "चाय"},
                "sample.morningRoutine.item2": {"en": "Breakfast", "hi": "नाश्ता"},
                "sample.morningRoutine.item2.notes": {"en": "Something light.", "hi": "हल्का"},
            }
        )
        with self.assertRaisesRegex(seeds.SeedError, "no translation for hi"):
            self._build(catalog)

    def test_seed_string_missing_from_the_catalog_fails_loudly(self) -> None:
        source = json.loads(json.dumps(SOURCE))
        source["checklists"][0]["items"][0]["name"] = "Walk the dog"
        with self.assertRaisesRegex(seeds.SeedError, "not in the catalog"):
            self._build(source=source)

    def test_duplicate_english_values_are_rejected_as_ambiguous(self) -> None:
        catalog = _catalog(
            {
                "sample.a.name": {"en": "Packing", "hi": "एक"},
                "sample.b.name": {"en": "Packing", "hi": "दो"},
            }
        )
        with self.assertRaisesRegex(seeds.SeedError, "ambiguous English value"):
            seeds.load_english_index(catalog)


class RepositorySeedTests(unittest.TestCase):
    def test_source_seed_regenerates_to_itself_byte_for_byte(self) -> None:
        # The strongest available check that the generator reproduces the
        # hand-authored source rather than merely something shaped like it.
        self.assertEqual(seeds.main(["--locales", "en-US", "--check"]), 0)

    def test_check_mode_reports_drift(self) -> None:
        catalog_path = seeds.CATALOG_PATH
        original = catalog_path.read_bytes()
        catalog = json.loads(original.decode("utf-8"))
        unit = catalog["strings"]["sample.morningRoutine.name"]["localizations"]["en"]
        unit["stringUnit"]["value"] = "Evening Routine"
        try:
            catalog_path.write_text(
                json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
            )
            self.assertEqual(seeds.main(["--locales", "en-US", "--check"]), 1)
        finally:
            catalog_path.write_bytes(original)


if __name__ == "__main__":
    unittest.main()
