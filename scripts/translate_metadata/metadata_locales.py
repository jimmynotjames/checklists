"""
Single source of truth for the App Store *metadata* localization pipeline.

This is the metadata sibling of scripts/translate_catalog/locales.py. Both target the
SAME markets, but use DIFFERENT locale code systems:

  * In-app strings (Localizable.xcstrings) use the app's *runtime* BCP 47 codes
    (`ar`, `de`, `nb`, `zh-Hans`, …).
  * App Store Connect *metadata* folders (fastlane/metadata/<storefront>/) use ASC
    *storefront* codes, which differ for several markets (`ar-SA`, `de-DE`, `no`,
    `nl-NL`, …). `deliver` reads the storefront-coded folders.

Both code systems, and the mapping between them, come from the locale registry in
fastlane/screenshot-config.json via locales.py — this module adds only the
metadata-specific facts (which fields are transcreated, the brand, cultural notes).

**Field limits are imported from scripts/appstore_metadata.py**, the validator that
actually gates the upload, so there is exactly one statement of Apple's limits in the
repo. Note `keywords` is limited in UTF-8 BYTES, not characters — a CJK or Indic
keyword list reaches the cap at roughly a third of the character count.
"""

from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

sys.path.insert(0, str(REPO_ROOT / "scripts" / "translate_catalog"))
sys.path.insert(0, str(REPO_ROOT / "scripts"))
from locales import (  # noqa: E402
    LOCALE_NAMES,
    RUNTIME_TO_STOREFRONT,
    STOREFRONT_TO_RUNTIME,
)
from appstore_metadata import FIELD_BY_FILENAME  # noqa: E402

# The English source storefront. Its folder holds the copy everything else is
# transcreated from. It is never itself a translation target.
SOURCE_LOCALE = "en-US"

# Brand token. Kept verbatim in every locale — never translated, transliterated, or
# re-cased.
BRAND = "reChecklist"

# The translation TARGET storefronts (sorted), excluding the en-US source.
STOREFRONT_LOCALES: list[str] = sorted(
    storefront for storefront in RUNTIME_TO_STOREFRONT.values() if storefront != SOURCE_LOCALE
)

# Human-readable name per storefront, derived from the registry's names.
STOREFRONT_NAMES: dict[str, str] = {
    storefront: LOCALE_NAMES[runtime]
    for runtime, storefront in RUNTIME_TO_STOREFRONT.items()
}


def _limit(field: str, attribute: str) -> int | None:
    return getattr(FIELD_BY_FILENAME[f"{field}.txt"], attribute)


# Apple's hard limits, taken from the shipping validator. Character counts are Unicode
# code points; the byte map below is what actually binds for `keywords`.
FIELD_LIMITS: dict[str, int] = {
    field: _limit(field, "max_characters")
    for field in ("name", "subtitle", "promotional_text", "description", "release_notes")
    if _limit(field, "max_characters") is not None
}
FIELD_BYTE_LIMITS: dict[str, int] = {
    field: _limit(field, "max_utf8_bytes")
    for field in ("keywords",)
    if _limit(field, "max_utf8_bytes") is not None
}
# `keywords` is byte-limited, so give it a character entry only as a loose upper bound
# for prompts and reports that want one number.
FIELD_LIMITS.setdefault("keywords", FIELD_BYTE_LIMITS["keywords"])

# Fields the pipeline transcreates, in order.
TRANSLATABLE_FIELDS: list[str] = [
    "subtitle",
    "promotional_text",
    "keywords",
    "description",
    "release_notes",
]

# Copied verbatim from en-US, never sent to a model. `name` is here because this app's
# store name is the bare brand: there is no descriptor to transcreate. Move it into
# TRANSLATABLE_FIELDS if a localized descriptor is ever added.
PASSTHROUGH_FIELDS: list[str] = [
    "name",
    "marketing_url",
    "privacy_url",
    "support_url",
]

# Catalog-level (not per-locale). Lives at fastlane/metadata/copyright.txt and is left
# untouched by this pipeline.
SHARED_FIELDS: list[str] = [
    "copyright",
]

# Static, field-level guidance injected into every prompt. Explains what each field is
# for and how to transcreate it, rather than translate it.
FIELD_GUIDANCE: dict[str, str] = {
    "subtitle": (
        "Short tagline shown under the app name. Punchy and concrete, not a literal "
        "translation of the English. Say what the app is for — checklists you reuse, "
        "reset, and run again. Title-case or sentence-case per local convention."
    ),
    "promotional_text": (
        "Short promotional banner (editable without shipping a new version). Lead with "
        "the most compelling current hook."
    ),
    "keywords": (
        "Comma-separated search terms, not a translation; follow the Keywords section. "
        "Fill as much of the byte budget as natural terms allow, and no more."
    ),
    "description": (
        "Full listing description. Transcreate into natural, native marketing prose — "
        "adapt idiom and flow, do not calque the English. Preserve the overall structure "
        "and the paragraph break."
    ),
    "release_notes": (
        "The \"What's New\" text on the update sheet. Match the tone of the English; keep "
        "it plain and concise."
    ),
}
