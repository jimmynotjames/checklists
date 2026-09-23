"""Rendered translation and audit prompts carry exactly the sections their slice needs."""

from __future__ import annotations

import importlib.util
import re
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = REPO_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS / "translate_catalog"))

import prompt_render  # noqa: E402
from locales import LOCALES  # noqa: E402

PLACEHOLDER = re.compile(r"\{[A-Z][A-Z_]*\}")


def _load(name: str, path: Path, dispatch_prompts=None):
    """Load a module by path. `dispatch_prompts` exists in two pipelines, so a module that
    imports it by bare name gets the right one pinned in sys.modules while it loads."""
    saved = sys.modules.get("dispatch_prompts")
    if dispatch_prompts is not None:
        sys.modules["dispatch_prompts"] = dispatch_prompts
    try:
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        if saved is None:
            sys.modules.pop("dispatch_prompts", None)
        else:
            sys.modules["dispatch_prompts"] = saved


catalog = _load("catalog_dispatch_prompts", SCRIPTS / "translate_catalog" / "dispatch_prompts.py")
audit = _load("audit_dispatch", SCRIPTS / "translate_audit" / "audit_dispatch.py", catalog)
metadata = _load("metadata_dispatch_prompts", SCRIPTS / "translate_metadata" / "dispatch_prompts.py")
semantic = _load("audit_semantic", SCRIPTS / "translate_metadata" / "audit_semantic.py", metadata)
from metadata_locales import STOREFRONT_LOCALES  # noqa: E402  (on the path once metadata loads)

UI_TEMPLATE = catalog.TEMPLATE_PATH.read_text(encoding="utf-8")
SAMPLE_TEMPLATE = catalog.SAMPLE_TEMPLATE_PATH.read_text(encoding="utf-8")
AUDIT_TEMPLATE = audit.TEMPLATE_PATH.read_text(encoding="utf-8")
METADATA_TEMPLATE = metadata.TEMPLATE_PATH.read_text(encoding="utf-8")
METADATA_AUDIT_TEMPLATE = semantic.TEMPLATE_PATH.read_text(encoding="utf-8")

FLAT = {"value": "Last updated: %@", "comment": "Caption.", "formatSpecifiers": ["%@"]}
PLURAL = {"plural": {"one": "%lld item", "other": "%lld items"}, "comment": "Count.", "formatSpecifiers": ["%lld"]}
NO_GLOSSARY_TERM = {"value": "Zzz", "comment": "Placeholder.", "formatSpecifiers": []}


def ui_prompt(locale: str, **source: dict) -> str:
    return catalog.render_prompt(UI_TEMPLATE, locale, {k: catalog.prompt_entry(v, locale) for k, v in source.items()})


def metadata_prompt(storefront: str, fields: list[str]) -> str:
    source = {f: {"value": f"English {f}", "charLimit": 100} for f in fields}
    return metadata.render_prompt(METADATA_TEMPLATE, storefront, metadata.build_prompt_source(fields, source))


class RenderTests(unittest.TestCase):
    def test_sections_render_only_when_enabled(self) -> None:
        template = "a\n<!-- if x -->\nX\n<!-- end x -->\nb\n"
        self.assertEqual(prompt_render.render(template, {}, {"x"}, known={"x"}), "a\nX\nb\n")
        self.assertEqual(prompt_render.render(template, {}, known={"x"}), "a\nb\n")

    def test_an_unknown_section_raises(self) -> None:
        with self.assertRaises(KeyError):
            prompt_render.render("<!-- if typo -->\nX\n<!-- end typo -->\n", {}, known={"x"})

    def test_an_unfilled_placeholder_raises(self) -> None:
        with self.assertRaises(KeyError):
            prompt_render.render("{LOCALE_NAME} {MISSING}", {"LOCALE_NAME": "German"})

    def test_substituted_values_are_not_rescanned(self) -> None:
        self.assertEqual(prompt_render.render("{A}", {"A": "{B}"}), "{B}")


class CatalogPromptTests(unittest.TestCase):
    def test_plural_rules_render_only_for_a_plural_slice(self) -> None:
        flat = ui_prompt("sl", **{"k.flat": FLAT})
        self.assertNotIn("## Plurals", flat)
        self.assertNotIn("requiredPluralCategories", flat)
        plural = ui_prompt("sl", **{"k.flat": FLAT, "k.plural": PLURAL})
        self.assertIn("## Plurals", plural)
        self.assertIn('"requiredPluralCategories":["one","two","few","other"]', plural)

    def test_format_specifiers_stay_out_of_the_slice(self) -> None:
        self.assertNotIn("formatSpecifiers", ui_prompt("de", **{"k": FLAT}))
        self.assertIn('"enChars":16', ui_prompt("de", **{"k": FLAT}))

    def test_glossary_section_carries_the_locale_slice_only_when_a_term_matches(self) -> None:
        terms = catalog.load_glossary()["terms"]
        with_term = ui_prompt("ja", **{"k": {"value": "Reset All", "comment": "", "formatSpecifiers": []}})
        self.assertIn("## Glossary", with_term)
        self.assertIn(f'- "Reset All" → "{terms["Reset All"]["translations"]["ja"]}"', with_term)
        self.assertNotIn("## Glossary", ui_prompt("ja", **{"k": NO_GLOSSARY_TERM}))

    def test_every_locale_gets_its_regional_note_and_no_placeholder(self) -> None:
        for locale in LOCALES:
            for template in (UI_TEMPLATE, SAMPLE_TEMPLATE):
                prompt = catalog.render_prompt(template, locale, {"sample.k": catalog.prompt_entry(FLAT, locale)})
                with self.subTest(locale=locale, template=template[:30]):
                    self.assertIn(catalog.REGIONAL_NOTES[locale], prompt)
                    self.assertIsNone(PLACEHOLDER.search(prompt))
                    self.assertNotIn("<!--", prompt)


class CatalogAuditPromptTests(unittest.TestCase):
    def audit_prompt(self, **source: dict) -> str:
        return audit.render_audit_prompt(AUDIT_TEMPLATE, "ru", source)

    def test_demo_and_plural_sections_render_only_when_the_slice_has_them(self) -> None:
        flat = {"english": "Zzz", "comment": "", "enChars": 3, "current": "Ззз", "currentChars": 3}
        plural = {"englishPlural": {"one": "%lld item", "other": "%lld items"}, "comment": "",
                  "currentPlural": {"one": "%lld", "other": "%lld"}}
        plain = self.audit_prompt(**{"k": flat})
        self.assertNotIn("Demo content", plain)
        self.assertNotIn("**Plurals.**", plain)
        self.assertNotIn("## Glossary", plain)
        self.assertIn("Demo content", self.audit_prompt(**{"sample.k": flat}))
        self.assertIn("**Plurals.**", self.audit_prompt(**{"k": plural}))

    def test_glossary_matches_plural_forms_too(self) -> None:
        plural = {"englishPlural": {"one": "%lld Checklist", "other": "%lld Checklists"}, "comment": "",
                  "currentPlural": {"one": "%lld", "other": "%lld"}}
        self.assertIn('- "Checklist" →', self.audit_prompt(**{"k": plural}))

    def test_every_locale_renders_without_a_placeholder(self) -> None:
        flat = {"english": "Reset", "comment": "", "enChars": 5, "current": "x", "currentChars": 1}
        for locale in LOCALES:
            prompt = audit.render_audit_prompt(AUDIT_TEMPLATE, locale, {"k": flat})
            with self.subTest(locale=locale):
                self.assertIn(catalog.REGIONAL_NOTES[locale], prompt)
                self.assertIn("## Glossary", prompt)
                self.assertIsNone(PLACEHOLDER.search(prompt))


class MetadataPromptTests(unittest.TestCase):
    def test_field_sections_render_only_for_fields_in_the_slice(self) -> None:
        only_keywords = metadata_prompt("de-DE", ["keywords"])
        self.assertIn("## Keywords", only_keywords)
        self.assertNotIn("## Subtitle", only_keywords)
        self.assertNotIn("## Longer fields", only_keywords)
        only_notes = metadata_prompt("de-DE", ["release_notes"])
        self.assertIn("## Longer fields", only_notes)
        self.assertNotIn("## Keywords", only_notes)
        self.assertIn("## Subtitle", metadata_prompt("de-DE", ["subtitle"]))

    def test_keywords_carry_a_byte_limit(self) -> None:
        prompt = metadata_prompt("ja", ["keywords", "subtitle"])
        self.assertIn('"keywords":{"byteLimit":100', prompt)
        self.assertIn('"subtitle":{"charLimit":100', prompt)

    def test_every_storefront_gets_its_note_the_literal_brand_and_no_placeholder(self) -> None:
        for storefront in STOREFRONT_LOCALES:
            prompt = metadata_prompt(storefront, ["subtitle", "keywords", "description"])
            with self.subTest(storefront=storefront):
                self.assertIn(metadata.CULTURAL_NOTES[storefront], prompt)
                self.assertIn("reChecklist", prompt)
                self.assertIsNone(PLACEHOLDER.search(prompt))
                self.assertNotIn("<!--", prompt)


class MetadataAuditPromptTests(unittest.TestCase):
    def audit_prompt(self, storefront: str) -> str:
        field = semantic.audit_field("Zzz", "keywords", measure=True)
        return semantic.render_audit_prompt(METADATA_AUDIT_TEMPLATE, storefront, {"keywords": field},
                                            {"keywords": field})

    def test_rtl_placement_renders_only_for_rtl_storefronts(self) -> None:
        for storefront in ("ar-SA", "he", "ur-PK"):
            self.assertIn("RTL brand placement", self.audit_prompt(storefront))
        self.assertNotIn("RTL brand placement", self.audit_prompt("de-DE"))

    def test_keywords_are_measured_in_bytes(self) -> None:
        self.assertEqual(semantic.audit_field("日本", "keywords", measure=True),
                         {"value": "日本", "byteLimit": 100, "bytes": 6})

    def test_every_storefront_renders_its_note_without_a_placeholder(self) -> None:
        for storefront, note in metadata.CULTURAL_NOTES.items():
            prompt = self.audit_prompt(storefront)
            with self.subTest(storefront=storefront):
                self.assertIn(note, prompt)
                self.assertIsNone(PLACEHOLDER.search(prompt))


if __name__ == "__main__":
    unittest.main()
