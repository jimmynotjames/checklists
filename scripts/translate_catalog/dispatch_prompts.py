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
try:
    from plural_rules import PLURAL_RULES  # noqa: E402
except Exception:
    PLURAL_RULES = {}  # the template then falls back to "the categories the locale needs"

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
        known={"plural", "glossary"},
    )


def prompt_entry(entry: dict, locale: str) -> dict:
    """A source.json entry as the translator sees it."""
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
    "ar": "Modern Standard Arabic (MSA), not a regional dialect. MSA has no polite/casual pronoun split: address the reader with the standard second-person singular (generic masculine), prefer verbal nouns (e.g. \"إضافة\") for labels and buttons, and get a warm, contemporary feel through fresh, light phrasing. Right-to-left: keep punctuation and any Latin tokens (e.g. \"iCloud\") correctly placed for RTL, and never start a string or sentence with a Latin token, which renders flung to the visual end of the line; lead with a native word.",
    "bn": "Conversational Bengali (Bangla) in Bengali script. Keep the polite \"আপনি\" — Bengali app copy addresses all audiences politely; the casual \"তুমি\"/\"তুই\" reads as overfamiliar, not young. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "ca": "Use the informal \"tu\", not \"vostè\" — the everyday address in Apple's Catalan UI and mainstream Catalan apps, natural for readers of every age. Natural, friendly Catalan as used in Apple's Catalan UI; warmth comes from clear, unfussy phrasing, not slang.",
    "cs": "Use the polite \"vy\" (vykání: second-person plural verb forms, lowercase \"vy/váš\") — the respectful norm in Apple's Czech UI and mainstream Czech apps; \"ty\" still reads overfamiliar to many readers. Warmth comes from modern, natural phrasing over literal calques, not from tykání; avoid stiff officialese.",
    "da": "Use the informal \"du\" — the universal address in Danish apps, Apple's included, for readers of every age (\"De\" reads archaic). Direct and plain.",
    "de": "Use the informal \"du\" — Apple's German UI and most mainstream German apps now address readers of every age with \"du\". Keep it respectful: warm and direct, never chummy or slangy; avoid stiff officialese and English calques. German typically runs longer than English — keep compounds tight so labels don't overflow.",
    "el": "Use the polite plural \"εσείς\" (plural verb forms and \"σας\") — the respectful norm in Apple's Greek UI and mainstream Greek apps and banks; the singular \"εσύ\" reads overfamiliar to older readers. Warmth comes from modern, everyday Greek; avoid overly formal or bureaucratic phrasing.",
    "en-AU": "Australian English spelling and idiom (e.g. \"organise\", \"colour\"). Relaxed, friendly tone.",
    "en-CA": "Canadian English spelling (mostly British: \"colour\", \"centre\").",
    "en-GB": "British English spelling and idiom (e.g. \"organise\", \"colour\", \"centre\").",
    "es": "Castilian Spanish; use the informal \"tú\", not \"usted\" — Apple Spain and mainstream Spanish apps and banks address readers of every age with \"tú\". Spain vocabulary (e.g. \"móvil\"). Modern and relaxed, never slangy.",
    "es-MX": "Latin American Spanish; use the informal \"tú\", not \"usted\" — Apple's Latin American UI and mainstream apps, banking included, use it with readers of every age; keep it courteous, never slangy. Neutral LatAm vocabulary (e.g. \"celular\"); avoid Spain-specific terms.",
    "fi": "Use the informal second-person singular (sinä forms, mostly implicit in the verb, e.g. \"Lisää\") — the universal address in Finnish apps, Apple's included, for readers of every age; the plural \"te\" reads stiff. Direct, natural Finnish app tone, not literal. Finnish runs long — keep UI labels tight.",
    "fr": "Use the polite \"vous\" — Apple's French UI and mainstream French apps (banks, retail, transport) address readers with \"vous\", and \"tu\" from an app still reads presumptuous to many. Warmth comes from clear, light, unfussy phrasing, never stiff administrative French. Keep it concise; prefer natural French terms over anglicisms. French app copy prizes clarté and a refined, slightly understated register over an enthusiastic one.",
    "fr-CA": "Canadian French; use the polite \"vous\" — Apple's Canadian French UI and mainstream Québec banking and public-service apps keep \"vous\" even though \"tu\" is common in speech. Warmth comes from plain, friendly phrasing, not tutoiement. Prefer Québécois usage and OQLF-style avoidance of anglicisms where they differ from France French.",
    "gu": "Conversational Gujarati in Gujarati script. Keep the polite \"તમે\" — Gujarati app copy stays polite across audiences; the casual \"તું\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "he": "Modern Hebrew, with no polite/casual pronoun split; the real choice is gender — avoid gendered second-person forms: use infinitives for actions (e.g. \"להוסיף\") and noun phrases for labels, and where direct address is unavoidable use plural imperatives (e.g. \"הוסיפו\"), never slash forms. Right-to-left: keep punctuation and any Latin tokens (e.g. \"iCloud\") correctly placed for RTL, and never start a string or sentence with a Latin token, which renders flung to the visual end of the line; lead with a native word. Friendly register.",
    "hi": "Conversational Hindi in Devanagari. Keep the polite \"आप\" — Hindi app copy uses \"आप\" across audiences; \"तू\" would read as rude, not young. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "hr": "Use the polite \"vi\" (second-person plural verb forms, lowercase \"vi/vaš\") — the respectful norm in Apple's Croatian UI and mainstream Croatian apps and banks; \"ti\" reads overfamiliar to older readers. Warmth comes from modern, natural phrasing, not calqued and not informal.",
    "hu": "Use polite address (magázás) through formal third-person verb forms (e.g. \"Adja meg\", \"listája\"), using \"Ön\" only when a pronoun is unavoidable and never \"maga\" — the respectful norm in Apple's Hungarian UI and mainstream banks; tegezés still reads overfamiliar to older readers. Warmth comes from modern, plain phrasing, never stiff or bureaucratic register. Hungarian runs long — keep labels tight.",
    "id": "Use the polite \"Anda\" — the standard written address in Apple's Indonesian UI, banks and official copy, respectful to readers of every age; the casual \"kamu\" can read overfamiliar to older readers. Warmth comes from friendly, plain everyday Indonesian as used in popular consumer apps, not slang.",
    "it": "Use the informal \"tu\" — Apple's Italian UI and mainstream Italian apps and banks address readers of every age with \"tu\"; \"Lei\" reads stiff. Natural, courteous Italian, never slangy; avoid unnecessary anglicisms.",
    "ja": "Keep polite-friendly です/ます — Japanese app copy stays polite regardless of audience age; plain/casual form reads as off, not young. Get warmth through light, soft, approachable phrasing (Apple Japan's voice), not by dropping politeness; avoid stiff keigo. Use katakana for loanwords (e.g. アプリ). The English em-dash habit does not translate — restructure instead.",
    "kn": "Natural Kannada in Kannada script. Keep the polite \"ನೀವು\" — Kannada app copy stays polite across audiences; the casual \"ನೀನು\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "ko": "Use the polite-friendly 해요체 throughout — Korean app copy stays polite across ages; plain 반말 reads as wrong, and the stiffer 합니다체 reads distant, so don't drift into it (short button labels can stay noun forms). Warmth comes from clean, light phrasing and natural English loanwords (common in Korean tech), not from dropping politeness. Match Apple Korea's voice.",
    "ml": "Natural Malayalam in Malayalam script. Keep the polite \"നിങ്ങൾ\" — Malayalam app copy addresses all audiences politely; the casual \"നീ\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "mr": "Conversational Marathi in Devanagari. Keep the polite \"तुम्ही\" — Marathi app copy stays polite across audiences; \"तू\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "ms": "Use the polite, neutral \"anda\" — the standard address in Apple's Malay UI and mainstream Malaysian apps and banks for readers of every age; casual \"awak\"/\"kau\" read overfamiliar. Warmth comes from friendly, natural Malay as used in consumer apps, not slang.",
    "nb": "Norwegian (Bokmål); use the informal \"du\" — the universal address in Norwegian apps, Apple's included, for readers of every age (\"De\" reads archaic). Direct and plain.",
    "nl": "Use the informal \"je\" — Apple's Dutch UI and mainstream Dutch apps and banks address readers of every age with \"je\"; \"u\" reads distant. Modern, relaxed, courteous register.",
    "or": "Natural Odia in Odia script. Keep the polite \"ଆପଣ\" — Odia app copy stays polite across audiences; the casual \"ତୁମେ\"/\"ତୁ\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "pa": "Conversational Punjabi in Gurmukhi (Indian Punjabi) script. Keep the polite \"ਤੁਸੀਂ\" — Punjabi app copy stays polite across audiences; \"ਤੂੰ\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "pl": "Use the informal second-person singular (imperatives like \"Dodaj\", and the courtesy capital \"Twój/Twoja\" when a possessive is needed) — the standard address in Polish software, Apple's included, and mainstream banking apps, for readers of every age; \"Pan/Pani\" is clumsy in UI. Friendly, natural, not stiff.",
    "pt-BR": "Brazilian Portuguese; use \"você\" — Brazil's natural, respectful everyday address, used by Apple and mainstream apps for readers of every age (\"o senhor/a senhora\" is ceremonious, \"tu\" regional). Warm, not slangy. Brazilian orthography and vocabulary.",
    "pt-PT": "European Portuguese; use polite third-person address — third-person verbs with \"o seu/a sua\", leaving the pronoun \"você\" out (it can read curt) — as Apple Portugal and mainstream Portuguese banks and retailers do; \"tu\" reads overfamiliar to older readers. Warmth comes from light, direct phrasing, not tutear. European orthography and vocabulary; avoid Brazilian-specific terms.",
    "ro": "Use the polite second-person plural (dumneavoastră verb forms, e.g. \"Adăugați\"; write the pronoun out, not \"dvs.\", and only when unavoidable) — the respectful norm in Apple's Romanian UI and mainstream Romanian apps and banks; \"tu\" reads overfamiliar to older readers. Warmth comes from modern, natural phrasing, not informality.",
    "ru": "Use the polite \"вы\" (lowercase, as in UI copy) — Apple's Russian UI and mainstream Russian apps and banks address readers with \"вы\"; \"ты\" from an app reads overfamiliar. Warmth comes from natural, light, non-calque Russian, not bureaucratic канцелярит.",
    "sk": "Use the polite \"vy\" (vykanie: second-person plural verb forms, lowercase \"vy/váš\") consistently, never mixing in tykanie — the respectful norm in Apple's Slovak UI and mainstream Slovak apps and banks. Warmth comes from modern, natural phrasing, not informality.",
    "sl": "Use the polite \"vi\" (vikanje: second-person plural verb forms, lowercase) — the respectful norm in Apple's Slovenian UI and mainstream Slovenian apps and banks; \"ti\" reads overfamiliar to older readers. Warmth comes from natural, non-calqued phrasing, not tikanje. Note Slovenian's dual number: count-dependent strings need the dual (\"two\") form, not just one/other.",
    "sv": "Use the informal \"du\" — the universal address in Swedish apps, Apple's included, for readers of every age (\"ni\" reads stiff). Direct and plain.",
    "ta": "Natural Tamil in Tamil script. Keep the polite \"நீங்கள்\" — Tamil app copy stays polite across audiences; the casual \"நீ\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "te": "Natural Telugu in Telugu script. Keep the polite \"మీరు\" — Telugu app copy stays polite across audiences; the casual \"నువ్వు\" reads as overfamiliar. The modern feel comes from warmth, brevity, and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "th": "Polite, friendly Thai — address the reader as \"คุณ\" or leave the pronoun out, and get politeness from polite phrasing (e.g. โปรด/กรุณา where natural), not from the speaker-gendered particles ครับ/ค่ะ, which UI strings don't use; the modern feel comes from light, contemporary phrasing, not from dropping politeness. Follow normal Thai spacing conventions.",
    "tr": "Use the polite \"siz\" (plural verb forms and suffixes, e.g. \"Ekleyin\", \"listeniz\"); short button labels may use the bare stem (\"Ekle\", \"Sil\") as Turkish UI normally does. Apple's Turkish UI and mainstream Turkish banks and retailers address readers with \"siz\"; \"sen\" reads overfamiliar to older readers. Warmth comes from friendly, natural phrasing, not from \"sen\".",
    "uk": "Use the polite \"ви\" (lowercase, as in UI copy) — the respectful norm in Apple's Ukrainian UI and most mainstream Ukrainian apps and services; \"ти\" reads overfamiliar to older readers. Warmth comes from modern, natural phrasing, not calqued from Russian or English.",
    "ur": "Conversational Urdu in Nastaliq (Arabic) script. Keep the polite \"آپ\" — Urdu app copy uses \"آپ\" across audiences; \"تم\"/\"تو\" reads as overfamiliar or rude, not young. Right-to-left: keep punctuation and any Latin tokens (e.g. \"iCloud\") correctly placed for RTL, and never start a string or sentence with a Latin token, which renders flung to the visual end of the line; lead with a native word. The modern feel comes from warm, light phrasing and natural English loanwords (e.g. \"checklist\"), not informal pronouns.",
    "vi": "Address the reader as \"bạn\", or leave the pronoun out — the neutral, respectful address of Apple's Vietnamese UI and mainstream Vietnamese apps for readers of every age; never casual pronouns like \"cậu\"/\"mày\", and not the service-counter \"quý khách\". Friendly, natural Vietnamese as used in popular consumer apps.",
    "zh-Hans": "Simplified Chinese, mainland China conventions. Address the reader as \"你\" consistently, as Apple's mainland UI and mainstream apps do for readers of every age; \"您\" reads like a bank or customer-service script. Concise, modern app tone; avoid Taiwan-specific vocabulary. Mainland copy is punchy and benefit-dense — short rhythms land well, but keep it calm and avoid exclamation-heavy hype.",
    "zh-Hant": "Traditional Chinese, Taiwan conventions. Address the reader as \"你\" consistently, as Apple Taiwan's UI does for readers of every age; don't drift into \"您\" (e.g. in iCloud or sync messages), which reads like a bank or customer-service script. Concise, modern app tone; avoid mainland-specific vocabulary.",
}

# Fallback for any locale without a specific note above: still steer register.
_GENERIC_NOTE = (
    "Write as a native speaker would for a modern consumer app: natural, idiomatic, "
    "never calqued. The voice is modern and respectful: current and unfussy, never stiff "
    "or old-fashioned, and never so casual that it would sound flippant to an older reader. "
    "Use the informal address where people of every generation would expect it from a "
    "modern app, and the polite form where that is still the respectful norm."
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
