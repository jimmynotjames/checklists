#!/usr/bin/env python3
"""
Render one transcreation prompt per storefront from tmp/metadata-inputs/{source,manifest}.json
into tmp/metadata-prompts/{S}.md, for `metadata-locale`.

Each prompt gets the storefront's CULTURAL_NOTES entry and only the fields it needs, each with
its English value, limit (`byteLimit` for keywords, else `charLimit`) and FIELD_GUIDANCE; the
subtitle, keywords and longer-field sections render only when the slice has those fields.
Unless --no-clean, deletes the storefronts' stale tmp/metadata-outputs/{S}.json first.

Usage: python3 scripts/translate_metadata/dispatch_prompts.py [--no-clean]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
METADATA_DIR = REPO_ROOT / "fastlane" / "metadata"
INPUTS_DIR = REPO_ROOT / "tmp" / "metadata-inputs"
PROMPTS_DIR = REPO_ROOT / "tmp" / "metadata-prompts"
OUTPUTS_DIR = REPO_ROOT / "tmp" / "metadata-outputs"
SOURCE_PATH = INPUTS_DIR / "source.json"
MANIFEST_PATH = INPUTS_DIR / "manifest.json"
TEMPLATE_PATH = Path(__file__).parent / "PROMPT_TEMPLATE.md"

sys.path.insert(0, str(Path(__file__).parent))
from metadata_locales import (  # noqa: E402
    FIELD_BYTE_LIMITS,
    FIELD_GUIDANCE,
    STOREFRONT_NAMES,
    glossary_lines,
    store_name,
)
from prompt_render import compact_json, render  # noqa: E402  (translate_catalog; metadata_locales puts it on the path)

PROSE_FIELDS = {"promotional_text", "description", "release_notes"}

# Marketing register, positioning and keyword notes, kept apart from the in-app REGIONAL_NOTES on
# purpose; change a formality call in both: localization-spec.md §Running the pipelines.
CULTURAL_NOTES: dict[str, str] = {
    "ar-SA": "Write in Modern Standard Arabic (MSA), not a regional dialect. Register: MSA has no polite/casual pronoun split — address the reader with the standard second-person singular (generic masculine) and achieve the modern feel through fresh, light, contemporary phrasing rather than colloquialism. Right-to-left: keep punctuation and any Latin brand tokens correctly placed for RTL. Never begin a line, sentence, or paragraph with a Latin token like reChecklist — a line that starts with a strong left-to-right word mis-renders and flings the token to the visual end; lead with a native (RTL) word and keep the brand mid-sentence. Warm but clean register. Positioning: being organised and prepared carries positive, prudent-stewardship connotations here — frame reChecklist as helping you keep things in order with dignity, never as fixing forgetfulness. Avoid imagery that implies the user is careless.",
    "bn-BD": "Conversational Bengali (Bangla) in Bengali script. Keep the polite \"আপনি\" — Bengali app copy stays polite across audiences; the casual \"তুমি\"/\"তুই\" reads as overfamiliar. Get the modern feel from warmth, brevity, and the natural English loanwords (\"checklist\", \"list\") Bengali speakers expect. Positioning: being organised and prepared carries positive, prudent-household connotations — frame reChecklist as keeping a household running calmly, never as fixing bad habits. Keyword/ASO: many users search in English or Roman-script transliteration, so mix natural Bengali-script terms with the common English loanwords people actually type.",
    "ca": "Use the informal \"tu\", not \"vostè\" — the everyday address in Apple's Catalan UI and mainstream Catalan apps, natural for readers of every age. Natural, friendly Catalan as used in Apple's Catalan UI; warmth comes from clear, unfussy phrasing, not slang.",
    "cs": "Use the polite \"vy\" (vykání: second-person plural verb forms, lowercase \"vy/váš\") — the respectful norm in Apple's Czech UI and mainstream Czech apps; \"ty\" still reads overfamiliar to many readers. Warmth comes from friendly, modern, natural phrasing over literal calques, not from tykání; avoid stiff officialese.",
    "da": "Use the informal \"du\" — the universal address in Danish apps, Apple's included, for readers of every age (\"De\" reads archaic). Direct and plain.",
    "de-DE": "Use the informal \"du\" — Apple's German UI and most mainstream German apps now address readers of every age with \"du\". Keep it respectful: warm and direct, never chummy or slangy; avoid stiff officialese and English calques. Positioning: German users value precision and substance over hype — lean into the calm, dependable traits and concrete benefits; understatement reads as credible here, marketing superlatives read as cheap.",
    "el": "Use the polite plural \"εσείς\" (plural verb forms and \"σας\") — the respectful norm in Apple's Greek UI and mainstream Greek apps and banks; the singular \"εσύ\" reads overfamiliar to older readers. Warmth comes from friendly, modern, everyday Greek; avoid overly formal or bureaucratic phrasing.",
    "en-AU": "Australian English spelling and idiom (e.g. \"organise\", \"colour\"). Relaxed, friendly tone.",
    "en-CA": "Canadian English spelling (mostly British: \"colour\", \"centre\").",
    "en-GB": "British English spelling and idiom (e.g. \"organise\", \"colour\", \"centre\").",
    "es-ES": "Castilian Spanish; use the informal \"tú\", not \"usted\" — Apple Spain and mainstream Spanish apps and banks address readers of every age with \"tú\". Spain vocabulary (e.g. \"móvil\"). Modern and relaxed, never slangy.",
    "es-MX": "Latin American Spanish; use the informal \"tú\", not \"usted\" — Apple's Latin American UI and mainstream apps, banking included, use it with readers of every age; keep it courteous and friendly, never slangy. Neutral LatAm vocabulary (e.g. \"celular\"); avoid Spain-specific terms.",
    "fi": "Use the informal second-person singular (sinä forms, mostly implicit in the verb) — the universal address in Finnish apps, Apple's included, for readers of every age; the plural \"te\" reads stiff. Friendly, direct Finnish app tone; natural, not literal.",
    "fr-FR": "Use the polite \"vous\" — Apple's French UI and mainstream French apps address readers with \"vous\", and \"tu\" from an app still reads presumptuous to many; warmth comes from clear, light, unfussy phrasing, never stiff administrative French. Keep it concise, and prefer natural French terms over anglicisms where one exists. Positioning: French app copy prizes elegance and clarté — a refined, slightly understated register beats an enthusiastic American one. Let the calm/tidy traits carry; avoid breathless tone and avoid franglais.",
    "fr-CA": "Canadian French; use the polite \"vous\" — Apple's Canadian French UI and mainstream Québec banking and public-service apps keep \"vous\" even though \"tu\" is common in speech; warmth comes from plain, friendly phrasing, not tutoiement. Prefer Québécois usage and OQLF-style avoidance of anglicisms where they differ from France French.",
    "gu-IN": "Conversational Gujarati in Gujarati script. Keep the polite \"તમે\" — Gujarati app copy stays polite across audiences; the casual \"તું\" reads as overfamiliar. Get the modern feel from warmth, brevity, and natural English loanwords (\"checklist\", \"list\"). Positioning: being organised and prepared carries positive, prudent-household connotations — frame reChecklist as keeping a household running calmly, never as fixing bad habits. Keyword/ASO: many users search in English or Roman-script transliteration, so mix natural Gujarati-script terms with the common English loanwords people actually type.",
    "he": "Modern Hebrew, with no polite/casual pronoun split; the real choice is gender — avoid gendered second-person forms: use infinitives and noun phrases, and where direct address is unavoidable use plural imperatives (e.g. \"הוסיפו\"), never slash forms. Right-to-left: keep punctuation and any Latin brand tokens correctly placed for RTL. Never begin a line, sentence, or paragraph with a Latin token like reChecklist — a line that starts with a strong left-to-right word mis-renders and flings the token to the visual end; lead with a native (RTL) word and keep the brand mid-sentence. Friendly register.",
    "hi": "Conversational Hindi in Devanagari. Register: keep the polite \"आप\" — Hindi app copy uses \"आप\" across audiences regardless of age; the informal \"तू\" would read as wrong/rude. Achieve the modern feel through warmth, brevity, and English loanwords (e.g. \"checklist\", \"list\") that Hindi speakers naturally expect, not through informal pronouns.",
    "hr": "Use the polite \"vi\" (second-person plural verb forms, lowercase \"vi/vaš\") — the respectful norm in Apple's Croatian UI and mainstream Croatian apps and banks; \"ti\" reads overfamiliar to older readers. Warmth comes from friendly, modern, natural phrasing, not informality.",
    "hu": "Use polite address (magázás) through formal third-person verb forms (e.g. \"Adja meg\", \"listája\"), using \"Ön\" only when a pronoun is unavoidable and never \"maga\" — the respectful norm in Apple's Hungarian UI and mainstream banks; tegezés still reads overfamiliar to older readers. Warmth comes from friendly, modern, plain phrasing; avoid stiff or bureaucratic register.",
    "id": "Use the polite \"Anda\" — the standard written address in Apple's Indonesian UI, banks and official copy, respectful to readers of every age; the casual \"kamu\" can read overfamiliar to older readers. Warmth comes from friendly, plain everyday Indonesian as used in popular consumer apps, not slang.",
    "it": "Use the informal \"tu\" — Apple's Italian UI and mainstream Italian apps and banks address readers of every age with \"tu\"; \"Lei\" reads stiff. Natural, courteous Italian, never slangy; avoid unnecessary anglicisms. Modern, relaxed register.",
    "ja": "Register: keep polite-friendly です/ます — Japanese app copy stays polite regardless of audience age; plain/casual form would read as off. Get the modern feel through light, soft, approachable phrasing (Apple Japan's voice), not through dropping politeness. Avoid stiff keigo. Use katakana for loanwords (e.g. アプリ). Positioning: Japanese app copy rewards quiet politeness, tidiness, and 'kawaii-adjacent' gentle warmth over bold claims — the calm/tidy/quietly-warm traits are a perfect fit; let them lead and keep superlatives out. Short, soft sentences; the em-dash habit of English does not translate, restructure instead. Keyword note: Japanese is not space-delimited, so the template's \"unbundle multi-word phrases into single comma-separated words\" rule does NOT apply mechanically — never split a term into individual characters or insert spaces. List each keyword as the complete, natural unit users actually type (kanji/katakana as appropriate, comma-separated), and prioritize correct standalone search terms over trying to engineer cross-field word recombinations.",
    "kn-IN": "Natural Kannada in Kannada script. Keep the polite \"ನೀವು\" — Kannada app copy stays polite across audiences; the casual \"ನೀನು\" reads as overfamiliar. Get the modern feel from warmth, brevity, and natural English loanwords (\"checklist\", \"list\"). Positioning: being organised and prepared carries positive, prudent-household connotations — frame reChecklist as keeping a household running calmly, never as fixing bad habits. Keyword/ASO: many users search in English or Roman-script transliteration, so mix natural Kannada-script terms with the common English loanwords people actually type.",
    "ko": "Register: use the polite-friendly 해요체 throughout — Korean app copy stays polite across ages; plain 반말 reads as wrong, and the stiffer 합니다체 reads distant, so don't drift into it. The modern feel comes from clean, light phrasing and natural English loanwords (common in Korean tech), not from dropping politeness. Match Apple Korea's app voice. Positioning: clean, modern, lightly warm; lean into light/quick/effortless; avoid heavy or preachy framing about being more productive. Keyword note: Korean does use spaces between words, but do not over-split terms into syllables or particles to chase the template's recombination rule — list each keyword as the complete unit users actually type (comma-separated), favoring the natural search terms (including common English loanwords) over engineered fragments.",
    "ml-IN": "Natural Malayalam in Malayalam script. Keep the polite \"നിങ്ങൾ\" — Malayalam app copy addresses all audiences politely; the casual \"നീ\" reads as overfamiliar. Get the modern feel from warmth, brevity, and natural English loanwords (\"checklist\", \"list\"). Positioning: being organised and prepared carries positive, prudent-household connotations — frame reChecklist as keeping a household running calmly, never as fixing bad habits. Keyword/ASO: many users search in English or Roman-script transliteration, so mix natural Malayalam-script terms with the common English loanwords people actually type.",
    "mr-IN": "Conversational Marathi in Devanagari. Keep the polite \"तुम्ही\" — Marathi app copy stays polite across audiences; \"तू\" reads as overfamiliar. Get the modern feel from warmth, brevity, and natural English loanwords (\"checklist\", \"list\"). Positioning: being organised and prepared carries positive, prudent-household connotations — frame reChecklist as keeping a household running calmly, never as fixing bad habits. Keyword/ASO: many users search in English or Roman-script transliteration, so mix natural Devanagari terms with the common English loanwords people actually type.",
    "ms": "Use the polite, neutral \"anda\" — the standard address in Apple's Malay UI and mainstream Malaysian apps and banks for readers of every age; casual \"awak\"/\"kau\" read overfamiliar. Warmth comes from friendly, natural Malay as used in consumer apps, not slang.",
    "nl-NL": "Use the informal \"je\" — Apple's Dutch UI and mainstream Dutch apps and banks address readers of every age with \"je\"; \"u\" reads distant. Modern, relaxed, courteous register.",
    "no": "Norwegian (Bokmål); use the informal \"du\" — the universal address in Norwegian apps, Apple's included, for readers of every age (\"De\" reads archaic). Direct and plain.",
    "or-IN": "Natural Odia in Odia script. Keep the polite \"ଆପଣ\" — Odia app copy stays polite across audiences; the casual \"ତୁମେ\"/\"ତୁ\" reads as overfamiliar. Get the modern feel from warmth, brevity, and natural English loanwords (\"checklist\", \"list\"). Positioning: being organised and prepared carries positive, prudent-household connotations — frame reChecklist as keeping a household running calmly, never as fixing bad habits. Keyword/ASO: many users search in English or Roman-script transliteration, so mix natural Odia-script terms with the common English loanwords people actually type.",
    "pa-IN": "Conversational Punjabi in Gurmukhi (Indian Punjabi) script. Keep the polite \"ਤੁਸੀਂ\" — Punjabi app copy stays polite across audiences; \"ਤੂੰ\" reads as overfamiliar. Get the modern feel from warmth, brevity, and natural English loanwords (\"checklist\", \"list\"). Positioning: being organised and prepared carries positive, prudent-household connotations — frame reChecklist as keeping a household running calmly, never as fixing bad habits. Keyword/ASO: many users search in English or Roman-script transliteration, so mix natural Gurmukhi terms with the common English loanwords people actually type.",
    "pl": "Use the informal second-person singular (imperatives like \"Dodaj\", and the courtesy capital \"Twój/Twoja\" when a possessive is needed) — the standard address in Polish software, Apple's included, and mainstream banking apps, for readers of every age; \"Pan/Pani\" is clumsy in UI. Friendly, natural, not stiff.",
    "pt-BR": "Brazilian Portuguese; use \"você\" — Brazil's natural, respectful everyday address, used by Apple and mainstream apps for readers of every age (\"o senhor/a senhora\" is ceremonious, \"tu\" regional). Brazilian orthography and vocabulary. Modern, warm, friendly register. \"Checklist\" is masculine, as in the app (\"o checklist\", \"seus checklists\").",
    "pt-PT": "European Portuguese; use polite third-person address — third-person verbs with \"o seu/a sua\", leaving the pronoun \"você\" out (it can read curt) — as Apple Portugal and mainstream Portuguese banks and retailers do; \"tu\" reads overfamiliar to older readers. Warmth comes from light, direct phrasing, not tutear. European orthography and vocabulary; avoid Brazilian-specific terms.",
    "ro": "Use the polite second-person plural (dumneavoastră verb forms, e.g. \"Adăugați\"; write the pronoun out, not \"dvs.\", and only when unavoidable) — the respectful norm in Apple's Romanian UI and mainstream Romanian apps and banks; \"tu\" reads overfamiliar to older readers. Warmth comes from friendly, modern, natural phrasing, not informality.",
    "ru": "Use the polite \"вы\" (lowercase, as in UI copy) — Apple's Russian UI and mainstream Russian apps and banks address readers with \"вы\"; \"ты\" from an app reads overfamiliar. Warmth comes from natural, light, relaxed non-calque Russian, not bureaucratic канцелярит.",
    "sk": "Use the polite \"vy\" (vykanie: second-person plural verb forms, lowercase \"vy/váš\") consistently, never mixing in tykanie — the respectful norm in Apple's Slovak UI and mainstream Slovak apps and banks. Warmth comes from friendly, modern, natural phrasing, not informality.",
    "sl-SI": "Use the polite \"vi\" (vikanje: second-person plural verb forms, lowercase) — the respectful norm in Apple's Slovenian UI and mainstream Slovenian apps and banks; \"ti\" reads overfamiliar to older readers. Warmth comes from natural, non-calqued phrasing, not tikanje; avoid stiff or bureaucratic register. Let the calm/tidy traits carry rather than marketing hype.",
    "sv": "Use the informal \"du\" — the universal address in Swedish apps, Apple's included, for readers of every age (\"ni\" reads stiff). Direct and plain.",
    "ta-IN": "Natural Tamil in Tamil script. Keep the polite \"நீங்கள்\" — Tamil app copy stays polite across audiences; the casual \"நீ\" reads as overfamiliar. Get the modern feel from warmth, brevity, and natural English loanwords (\"checklist\", \"list\"). Positioning: being organised and prepared carries positive, prudent-household connotations — frame reChecklist as keeping a household running calmly, never as fixing bad habits. Keyword/ASO: many users search in English or Roman-script transliteration, so mix natural Tamil-script terms with the common English loanwords people actually type.",
    "te-IN": "Natural Telugu in Telugu script. Keep the polite \"మీరు\" — Telugu app copy stays polite across audiences; the casual \"నువ్వు\" reads as overfamiliar. Get the modern feel from warmth, brevity, and natural English loanwords (\"checklist\", \"list\"). Positioning: being organised and prepared carries positive, prudent-household connotations — frame reChecklist as keeping a household running calmly, never as fixing bad habits. Keyword/ASO: many users search in English or Roman-script transliteration, so mix natural Telugu-script terms with the common English loanwords people actually type.",
    "th": "Polite, friendly Thai — address the reader as \"คุณ\" or leave the pronoun out, and get politeness from polite phrasing (e.g. โปรด/กรุณา where natural), not from the speaker-gendered particles ครับ/ค่ะ, which UI strings don't use; the modern feel comes from light, friendly, contemporary phrasing, not from dropping politeness. Follow normal Thai spacing conventions; keep it light and approachable.",
    "tr": "Use the polite \"siz\" (plural verb forms and suffixes, e.g. \"Ekleyin\", \"listeniz\") — Apple's Turkish UI and mainstream Turkish banks and retailers address readers with \"siz\"; \"sen\" reads overfamiliar to older readers. Warmth comes from friendly, natural phrasing, not from \"sen\".",
    "uk": "Use the polite \"ви\" (lowercase, as in UI copy) — the respectful norm in Apple's Ukrainian UI and most mainstream Ukrainian apps and services; \"ти\" reads overfamiliar to older readers. Warmth comes from friendly, modern, natural phrasing, not calqued from Russian or English.",
    "ur-PK": "Conversational Urdu in Nastaliq (Arabic) script. Keep the polite \"آپ\" — Urdu app copy uses \"آپ\" across audiences; \"تم\"/\"تو\" reads as overfamiliar or rude. Right-to-left: keep punctuation and any Latin brand/tech tokens (\"reChecklist\", \"iCloud\") correctly placed for RTL. Never begin a line, sentence, or paragraph with a Latin token like reChecklist — a line that starts with a strong left-to-right word mis-renders and flings the token to the visual end; lead with a native (RTL) word and keep the brand mid-sentence (note: Urdu postpositions like \"کے ساتھ\" still leave reChecklist line-initial, so front a different word). Positioning: being organised and prepared carries positive, prudent-stewardship connotations — frame reChecklist as keeping things in order with dignity, never as fixing forgetfulness. Get the modern feel from warm, light phrasing and natural English loanwords (\"checklist\", \"list\"), not informal pronouns. As in the app, pluralize \"چیک لسٹ\" as \"چیک لسٹیں\" (oblique \"چیک لسٹوں\"), never \"چیک لسٹس\". Keyword/ASO: many users search in English or Roman-Urdu transliteration, so mix natural Urdu-script terms with the common English loanwords people actually type.",
    "vi": "Address the reader as \"bạn\", or leave the pronoun out — the neutral, respectful address of Apple's Vietnamese UI and mainstream Vietnamese apps for readers of every age; never casual pronouns like \"cậu\"/\"mày\", and not the service-counter \"quý khách\". Friendly, natural Vietnamese as used in popular consumer apps.",
    "zh-Hans": "Simplified Chinese, mainland China conventions. Address the reader as \"你\" consistently, as Apple's mainland UI and mainstream apps do for readers of every age; \"您\" reads like a bank or customer-service script. Concise, modern app tone; avoid Taiwan-specific vocabulary. Positioning: mainland app copy is punchy and benefit-dense — short four-character rhythms and concrete value land well, but keep it calm and avoid the exclamation-heavy hype common in local ads. Note: iCloud-based privacy framing is less of a selling point here; emphasize speed, simplicity, and everyday usefulness instead. Keyword note: Chinese is not space-delimited, so the template's \"unbundle multi-word phrases into single comma-separated words\" rule does NOT apply mechanically — never split a term into individual characters or insert spaces. List each keyword as the complete, natural unit users actually type (comma-separated), and prioritize correct standalone search terms over trying to engineer cross-field word recombinations.",
    "zh-Hant": "Traditional Chinese, Taiwan conventions. Address the reader as \"你\" consistently, as Apple Taiwan's UI does for readers of every age; don't drift into \"您\", which reads like a bank or customer-service script. Avoid mainland-specific vocabulary. Keyword note: Chinese is not space-delimited, so the template's \"unbundle multi-word phrases into single comma-separated words\" rule does NOT apply mechanically — never split a term into individual characters or insert spaces. List each keyword as the complete, natural unit users actually type (comma-separated), and prioritize correct standalone search terms over trying to engineer cross-field word recombinations.",
}

_GENERIC_NOTE = (
    "Write as a native marketer for this market would: natural, idiomatic, and "
    "benefit-driven. Avoid literal, calqued translations. The voice is modern and respectful: current and unfussy, never stiff "
    "or old-fashioned, and never so casual that it would sound flippant to an older reader. "
    "Use the informal address where people of every generation would expect it from a "
    "modern app, and the polite form where that is still the respectful norm."
)


def build_prompt_source(slice_fields: list[str], source: dict) -> dict:
    """Annotate each needed field with its English value, limit, and guidance."""
    out: dict[str, dict] = {}
    for field in slice_fields:
        if field not in source:
            continue
        limit_key = "byteLimit" if field in FIELD_BYTE_LIMITS else "charLimit"
        out[field] = {
            "english": source[field]["value"],
            limit_key: source[field]["charLimit"],
            "guidance": FIELD_GUIDANCE.get(field, ""),
        }
    return out


def render_prompt(template: str, storefront: str, prompt_source: dict) -> str:
    sections = {field for field in ("subtitle", "keywords") if field in prompt_source}
    if PROSE_FIELDS & prompt_source.keys():
        sections.add("prose")
    glossary = glossary_lines(storefront)
    if glossary:
        sections.add("glossary")
    return render(
        template,
        {
            "LOCALE_NAME": STOREFRONT_NAMES.get(storefront, storefront),
            "LOCALE_CODE": storefront,
            "CULTURAL_NOTE": CULTURAL_NOTES.get(storefront, _GENERIC_NOTE),
            "SOURCE_JSON": compact_json(prompt_source),
            "STORE_NAME": store_name(METADATA_DIR, storefront),
            "GLOSSARY": glossary,
        },
        sections,
        known={"subtitle", "keywords", "prose", "glossary"},
    )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--no-clean",
        action="store_true",
        help="Do not delete pre-existing tmp/metadata-outputs/{storefront}.json files.",
    )
    args = parser.parse_args(argv)

    if not SOURCE_PATH.exists() or not MANIFEST_PATH.exists():
        print(
            "ERROR: missing source.json or manifest.json. "
            "Run `python3 scripts/translate_metadata/extract.py --missing` first.",
            file=sys.stderr,
        )
        return 1

    with SOURCE_PATH.open(encoding="utf-8") as f:
        source: dict = json.load(f)
    with MANIFEST_PATH.open(encoding="utf-8") as f:
        manifest: dict[str, list[str]] = json.load(f)
    template = TEMPLATE_PATH.read_text(encoding="utf-8")

    if not manifest:
        print("Manifest is empty — no prompts to write.")
        return 0

    PROMPTS_DIR.mkdir(parents=True, exist_ok=True)
    for existing in PROMPTS_DIR.glob("*.md"):
        existing.unlink()

    if not args.no_clean and OUTPUTS_DIR.exists():
        cleaned = 0
        for storefront in manifest:
            stale = OUTPUTS_DIR / f"{storefront}.json"
            if stale.exists():
                stale.unlink()
                cleaned += 1
        if cleaned:
            print(f"Cleaned {cleaned} stale output file(s) from {OUTPUTS_DIR}")

    for storefront in sorted(manifest):
        slice_fields = manifest[storefront]
        prompt_source = build_prompt_source(slice_fields, source)
        if not prompt_source:
            continue
        prompt = render_prompt(template, storefront, prompt_source)
        out_path = PROMPTS_DIR / f"{storefront}.md"
        out_path.write_text(prompt, encoding="utf-8")
        print(f"  Wrote {len(prompt_source)} field(s) for {storefront} → {out_path}")

    print(f"\n{len(manifest)} prompt file(s) written to {PROMPTS_DIR}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
