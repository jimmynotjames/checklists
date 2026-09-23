#!/usr/bin/env python3
"""
Render one translation prompt per locale from tmp/translate-inputs/{source,manifest}.json.

UI keys go to tmp/translate-prompts/{L}.md (PROMPT_TEMPLATE.md, `translation-locale`);
`sample.*` keys go to {L}.sample.md (SAMPLE_PROMPT_TEMPLATE.md, `sample-content-locale`).
Each prompt gets the locale's regional note, its glossary slice, and only the keys it needs;
the plural and glossary sections render only when the slice has a plural or a glossary match.
Unless --no-clean, deletes that locale's stale tmp/translate-outputs/{L}.json and
{L}.sample.json first, so validate --subset never sees a prior run's keys.

Usage: python3 scripts/translate_catalog/dispatch_prompts.py [--no-clean]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
INPUTS_DIR = REPO_ROOT / "tmp" / "translate-inputs"
PROMPTS_DIR = REPO_ROOT / "tmp" / "translate-prompts"
OUTPUTS_DIR = REPO_ROOT / "tmp" / "translate-outputs"
SOURCE_PATH = INPUTS_DIR / "source.json"
MANIFEST_PATH = INPUTS_DIR / "manifest.json"
TEMPLATE_PATH = Path(__file__).parent / "PROMPT_TEMPLATE.md"
SAMPLE_TEMPLATE_PATH = Path(__file__).parent / "SAMPLE_PROMPT_TEMPLATE.md"
GLOSSARY_PATH = Path(__file__).parent / "glossary.json"

# Demo-content key prefixes, transcreated by their own agent and template:
# localization-spec.md §Transcreation vs translation.
TRANSCREATED_NAMESPACES: tuple[str, ...] = ("sample.",)


def is_transcreated(key: str) -> bool:
    return key.startswith(TRANSCREATED_NAMESPACES)


sys.path.insert(0, str(Path(__file__).parent))
from locales import LOCALE_NAMES  # noqa: E402
from prompt_render import compact_json, render  # noqa: E402

# The exact CLDR categories each locale needs, injected per plural entry so the model never
# recalls them from memory. plural_rules.py imports nothing, so this cross-package import is safe.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "translate_audit"))
from plural_rules import PLURAL_RULES  # noqa: E402

_GLOSSARY_CACHE: dict | None = None


def load_glossary() -> dict:
    """Load glossary.json once; tolerate absence (returns empty terms)."""
    global _GLOSSARY_CACHE
    if _GLOSSARY_CACHE is None:
        if GLOSSARY_PATH.exists():
            with GLOSSARY_PATH.open(encoding="utf-8") as f:
                _GLOSSARY_CACHE = json.load(f)
        else:
            _GLOSSARY_CACHE = {"terms": {}}
    return _GLOSSARY_CACHE


def glossary_lines(values, locale: str) -> str:
    """Bullet list of the agreed `locale` rendering of every glossary term that appears
    (whole word or phrase) in any English `values`; "" when none match, which drops the
    template's glossary section. audit_dispatch.py uses it too."""
    terms = load_glossary().get("terms", {})
    haystack = "\n".join(values)
    matched: list[tuple[str, str]] = []
    for term_en in sorted(terms, key=lambda t: (-len(t), t.casefold())):  # longest-first
        translation = terms[term_en].get("translations", {}).get(locale)
        if translation and re.search(rf"\b{re.escape(term_en)}\b", haystack, flags=re.IGNORECASE):
            matched.append((term_en, translation))
    return "\n".join(f'- "{en}" → "{tr}"' for en, tr in matched)


def english_values(entry: dict) -> list[str]:
    """The English text of a flat (`value`) or plural (`plural`) source entry."""
    if entry.get("plural"):
        return list(entry["plural"].values())
    return [entry.get("value", "")]


def render_prompt(template: str, locale: str, stream_source: dict) -> str:
    glossary = glossary_lines([v for e in stream_source.values() for v in english_values(e)], locale)
    sections = {"plural"} if any("plural" in e for e in stream_source.values()) else set()
    if glossary:
        sections.add("glossary")
    return render(
        template,
        {
            "LOCALE_NAME": LOCALE_NAMES.get(locale, locale),
            "LOCALE_CODE": locale,
            "REGIONAL_NOTE": REGIONAL_NOTES.get(locale, _GENERIC_NOTE),
            "GLOSSARY": glossary,
            "SOURCE_JSON": compact_json(stream_source),
        },
        sections,
    )


def prompt_entry(entry: dict, locale: str) -> dict:
    """A source.json entry as the translator sees it: `enChars` added (plural keys measure
    `other`), `requiredPluralCategories` on plurals, `formatSpecifiers` left out."""
    out = {k: v for k, v in entry.items() if k != "formatSpecifiers"}
    out["enChars"] = len(entry.get("value") or (entry.get("plural") or {}).get("other", ""))
    if entry.get("plural"):
        required = PLURAL_RULES.get(locale, {}).get("required")
        if required:
            out["requiredPluralCategories"] = required
    return out


# UI register, dialect and script notes. They are kept apart from the metadata CULTURAL_NOTES on
# purpose; change a formality call in both: localization-spec.md §Running the pipelines.
REGIONAL_NOTES: dict[str, str] = {
    "ar": "Modern Standard Arabic (MSA), not a regional dialect — MSA addresses all audiences with the same standard forms, so there is no casual/formal toggle; get a warm, contemporary feel through fresh, light phrasing. Right-to-left: keep punctuation and any Latin tokens (e.g. \"iCloud\") correctly placed for RTL, and never start a string or sentence with a Latin token, which renders flung to the visual end of the line; lead with a native word.",
    "bn": "Conversational Bengali (Bangla) in Bengali script. Keep the polite \"আপনি\" — Bengali app copy addresses all audiences politely; the casual \"তুমি\"/\"তুই\" reads as overfamiliar, not young. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "ca": "Natural, friendly Catalan as used in Apple's Catalan UI.",
    "cs": "Modern Czech app tone; natural phrasing over literal calques. The informal address is standard for consumer apps.",
    "da": "Informal, direct Danish — the norm for consumer apps.",
    "de": "Use the informal \"du\" — standard for German consumer apps aimed at younger users. Warm and direct; avoid stiff officialese and English calques. German typically runs longer than English — keep compounds tight so labels don't overflow.",
    "el": "Modern Greek; avoid overly formal or bureaucratic phrasing.",
    "en-AU": "Australian English spelling and idiom (e.g. \"organise\", \"colour\"). Relaxed, friendly tone.",
    "en-CA": "Canadian English spelling (mostly British: \"colour\", \"centre\").",
    "en-GB": "British English spelling and idiom (e.g. \"organise\", \"colour\", \"centre\").",
    "es": "Castilian Spanish; informal \"tú\" (standard for youth-oriented consumer apps), not a \"vosotros\"-formal register. Spain vocabulary (e.g. \"móvil\"). Modern, relaxed.",
    "es-MX": "Latin American Spanish; informal \"tú\". Neutral LatAm vocabulary (e.g. \"celular\"); avoid Spain-specific terms.",
    "fi": "Direct, natural Finnish app tone, not literal. Finnish runs long — keep UI labels tight.",
    "fr": "Use the informal \"tu\" — younger French lifestyle apps address under-35s with \"tu\". Elegant and concise; prefer natural French terms over anglicisms. French app copy prizes clarté and a refined, slightly understated register over an enthusiastic one.",
    "fr-CA": "Canadian French; informal \"tu\" (standard in Québécois consumer-app copy). Prefer Québécois usage and OQLF-style avoidance of anglicisms where they differ from France French.",
    "gu": "Conversational Gujarati in Gujarati script. Keep the polite \"તમે\" — Gujarati app copy stays polite across audiences; the casual \"તું\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "he": "Modern Hebrew. Right-to-left: keep punctuation and any Latin tokens (e.g. \"iCloud\") correctly placed for RTL, and never start a string or sentence with a Latin token, which renders flung to the visual end of the line; lead with a native word. Friendly register.",
    "hi": "Conversational Hindi in Devanagari. Keep the polite \"आप\" — Hindi app copy uses \"आप\" across audiences; \"तू\" would read as rude, not young. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "hr": "Modern Croatian; natural phrasing, not calqued.",
    "hu": "Modern Hungarian; avoid stiff or bureaucratic register. Hungarian runs long — keep labels tight.",
    "id": "Friendly, casual Indonesian as used in popular consumer apps.",
    "it": "Informal \"tu\" (standard for youth-oriented consumer apps). Natural Italian; avoid unnecessary anglicisms.",
    "ja": "Keep polite-friendly です/ます — Japanese app copy stays polite regardless of audience age; plain/casual form reads as off, not young. Get warmth through light, soft, approachable phrasing (Apple Japan's voice), not by dropping politeness; avoid stiff keigo. Use katakana for loanwords (e.g. アプリ). The English em-dash habit does not translate — restructure instead.",
    "kn": "Natural Kannada in Kannada script. Keep the polite \"ನೀವು\" — Kannada app copy stays polite across audiences; the casual \"ನೀನು\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "ko": "Use the polite-friendly 해요체 — Korean app copy stays polite across ages; plain 반말 reads as wrong, not young. Warmth comes from clean, light phrasing and natural English loanwords (common in Korean tech), not from dropping politeness. Match Apple Korea's voice.",
    "ml": "Natural Malayalam in Malayalam script. Keep the polite \"നിങ്ങൾ\" — Malayalam app copy addresses all audiences politely; the casual \"നീ\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "mr": "Conversational Marathi in Devanagari. Keep the polite \"तुम्ही\" — Marathi app copy stays polite across audiences; \"तू\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "ms": "Friendly, natural Malay as used in consumer apps.",
    "nb": "Informal, direct Norwegian (Bokmål) — the norm for consumer apps.",
    "nl": "Use the informal \"je\" — standard for Dutch consumer apps, especially for younger audiences (\"u\" reads as formal/older). Modern, relaxed register.",
    "or": "Natural Odia in Odia script. Keep the polite \"ଆପଣ\" — Odia app copy stays polite across audiences; the casual \"ତୁମେ\"/\"ତୁ\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "pa": "Conversational Punjabi in Gurmukhi (Indian Punjabi) script. Keep the polite \"ਤੁਸੀਂ\" — Punjabi app copy stays polite across audiences; \"ਤੂੰ\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "pl": "Modern Polish for young adults — use the informal \"Ty\" (direct address) rather than formal \"Pan/Pani\". Friendly, natural, not stiff.",
    "pt-BR": "Brazilian Portuguese; informal, warm \"você\" (the natural informal address in Brazil). Brazilian orthography and vocabulary.",
    "pt-PT": "European Portuguese; informal \"tu\" (standard in youth-oriented PT app copy; \"você\" reads as distant). European orthography and vocabulary; avoid Brazilian-specific terms.",
    "ro": "Modern Romanian; natural phrasing.",
    "ru": "Use the informal \"ты\" — modern Russian app copy for young adults uses \"ты\" to feel current and friendly. Natural, non-calque Russian.",
    "sk": "Modern Slovak; natural phrasing.",
    "sl": "Modern Slovenian for young adults — use the informal \"ti\" (the formal \"vi\" reads as distant/official in youth-oriented consumer-app copy). Natural, non-calqued phrasing. Note Slovenian's dual number: count-dependent strings need the dual (\"two\") form, not just one/other.",
    "sv": "Informal, direct Swedish — the norm for consumer apps.",
    "ta": "Natural Tamil in Tamil script. Keep the polite \"நீங்கள்\" — Tamil app copy stays polite across audiences; the casual \"நீ\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "te": "Natural Telugu in Telugu script. Keep the polite \"మీరు\" — Telugu app copy stays polite across audiences; the casual \"నువ్వు\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "th": "Polite, friendly Thai — keep the polite particles (ครับ/ค่ะ) Thai app copy uses across audiences; the modern feel comes from light, contemporary phrasing, not from dropping politeness. Follow normal Thai spacing conventions.",
    "tr": "Modern Turkish for young adults; use the informal \"sen\" (standard in youth-oriented app copy; \"siz\" reads as formal/older). Friendly and natural.",
    "uk": "Modern Ukrainian; natural phrasing, not calqued from Russian or English.",
    "ur": "Conversational Urdu in Nastaliq (Arabic) script. Keep the polite \"آپ\" — Urdu app copy uses \"آپ\" across audiences; \"تم\"/\"تو\" reads as overfamiliar or rude, not young. Right-to-left: keep punctuation and any Latin tokens (e.g. \"iCloud\") correctly placed for RTL, and never start a string or sentence with a Latin token, which renders flung to the visual end of the line; lead with a native word. The modern feel comes from warm, light phrasing and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "vi": "Friendly, natural Vietnamese as used in popular consumer apps.",
    "zh-Hans": "Simplified Chinese, mainland China conventions. Concise, modern app tone; avoid Taiwan-specific vocabulary. Mainland copy is punchy and benefit-dense — short rhythms land well, but keep it calm and avoid exclamation-heavy hype.",
    "zh-Hant": "Traditional Chinese, Taiwan conventions. Concise, modern app tone; avoid mainland-specific vocabulary.",
}

# Fallback for any locale without a specific note above: still steer register.
_GENERIC_NOTE = (
    "Write as a native speaker would for a modern consumer app: natural, idiomatic, "
    "never calqued. Register: use the informal address if modern youth-oriented app copy "
    "in this language uses it, but keep the polite/formal form if this language stays "
    "formal in app copy regardless of audience age — get the modern feel from fresh, light "
    "phrasing, not forced slang."
)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--no-clean",
        action="store_true",
        help="Do not delete pre-existing tmp/translate-outputs/{locale}.json files.",
    )
    args = parser.parse_args(argv)

    if not SOURCE_PATH.exists() or not MANIFEST_PATH.exists():
        print(
            "ERROR: missing source.json or manifest.json. "
            "Run `python3 scripts/translate_catalog/extract.py --missing` first.",
            file=sys.stderr,
        )
        return 1

    with SOURCE_PATH.open(encoding="utf-8") as f:
        source: dict = json.load(f)
    with MANIFEST_PATH.open(encoding="utf-8") as f:
        manifest: dict[str, list[str]] = json.load(f)
    template = TEMPLATE_PATH.read_text(encoding="utf-8")
    sample_template = SAMPLE_TEMPLATE_PATH.read_text(encoding="utf-8")

    if not manifest:
        print("Manifest is empty — no prompts to write.")
        return 0

    PROMPTS_DIR.mkdir(parents=True, exist_ok=True)
    # Clear stale prompt files so we don't accidentally dispatch yesterday's work.
    for existing in PROMPTS_DIR.glob("*.md"):
        existing.unlink()

    # Clear stale per-locale output files for the locales we're about to dispatch,
    # so subagents start from a clean slate and validate --subset doesn't trip on
    # leftover keys from a prior run on a different branch.
    if not args.no_clean and OUTPUTS_DIR.exists():
        cleaned = 0
        for locale in manifest:
            for stale in (OUTPUTS_DIR / f"{locale}.json", OUTPUTS_DIR / f"{locale}.sample.json"):
                if stale.exists():
                    stale.unlink()
                    cleaned += 1
        if cleaned:
            print(f"Cleaned {cleaned} stale output file(s) from {OUTPUTS_DIR}")

    ui_files = sample_files = 0
    for locale in sorted(manifest):
        slice_source = {k: prompt_entry(source[k], locale) for k in manifest[locale] if k in source}
        streams = (
            (template, "", {k: v for k, v in slice_source.items() if not is_transcreated(k)}),
            (sample_template, ".sample", {k: v for k, v in slice_source.items() if is_transcreated(k)}),
        )
        for stream_template, suffix, stream_source in streams:
            if not stream_source:
                continue
            out_path = PROMPTS_DIR / f"{locale}{suffix}.md"
            out_path.write_text(render_prompt(stream_template, locale, stream_source), encoding="utf-8")
            print(f"  Wrote {len(stream_source)} keys for {locale} → {out_path}")
            if suffix:
                sample_files += 1
            else:
                ui_files += 1

    print(
        f"\n{ui_files} UI prompt file(s) (translation-locale) and {sample_files} sample prompt file(s) "
        f"(sample-content-locale) written to {PROMPTS_DIR}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
