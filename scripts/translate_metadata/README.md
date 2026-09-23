# `translate_metadata/` — App Store listing transcreation pipeline

Fills `fastlane/metadata/<storefront>/*.txt` for all 49 target App Store
storefronts by transcreating the English (`en-US`) listing copy. This is the
App-Store-metadata sibling of `scripts/translate_catalog/` (which handles in-app
`Localizable.xcstrings`).

The two pipelines are deliberately separate because they use **different locale
code systems**:

| Pipeline | Codes | Source of truth |
|----------|-------|-----------------|
| `translate_catalog/` (in-app UI) | runtime BCP 47 (`de`, `nb`, `nl`, `ar`) | `Localizable.xcstrings` |
| `translate_metadata/` (this one)  | ASC storefront (`de-DE`, `no`, `nl-NL`, `ar-SA`) | `fastlane/metadata/en-US/` |

`metadata_locales.py` owns the `runtime → storefront` mapping so the two stay in lockstep.

The per-storefront register notes (`CULTURAL_NOTES` here, `REGIONAL_NOTES` in the in-app
pipeline) are duplicated on purpose: `localization-spec.md §Running the pipelines`.

## What it translates

Transcreated per storefront (with App Store Connect limits):

| Field | Limit | Notes |
|-------|-------|-------|
| `subtitle` | 30 | Punchy tagline. |
| `promotional_text` | 170 | Editable without a new app version. |
| `keywords` | 100 UTF-8 bytes | **Search terms**, not prose — comma-separated, no spaces, deduped. |
| `description` | 4000 | Full persuasive listing copy; structure preserved. |
| `release_notes` | 4000 | "What's New" text. |

Passthrough fields, copied verbatim from `en-US` by `merge.py` and never sent to the model:
`name` (the store name is the bare brand), `marketing_url`, `privacy_url`, `support_url`.
`merge.py --skip-urls` skips all four. The catalog-level `copyright.txt` is left untouched.

A translatable field that is blank or absent in `en-US` is unused; `merge.py` deletes it
from every storefront.

The brand **"reChecklist"** is treated as a proper noun everywhere: never translated,
transliterated, or glossed. (Decision: brand stays Latin in all locales — no
localized home-screen icon name / `InfoPlist.xcstrings` is required.)

## Running it

The `appstore-translate-metadata` skill owns the step-by-step flow, including the semantic
audit and remediation loop. `check_metadata.py` exiting 0 is the definition of done. Upload
with the `appstore-push-metadata` skill.

After an English copy edit, re-transcreate just the edited fields across every storefront
with `extract.py --fields <field> ...`, then continue the normal flow.

## Files

```
scripts/translate_metadata/
  metadata_locales.py   # storefront list, runtime→storefront map, field limits, brand, names
  check_source_voice.py # pre-flight: warn on exclamation marks / ALL-CAPS / superlatives in en-US source (--json)
  extract.py            # en-US/*.txt → tmp/metadata-inputs/source.json (--missing → absent-field manifest; --fields F… → force-re-translate edited field(s))
  dispatch_prompts.py   # source + manifest + PROMPT_TEMPLATE.md → tmp/metadata-prompts/{storefront}.md
  validate.py           # --subset; PASS/PENDING/FAIL; limits, keyword hygiene; --json
  audit.py              # inspect outputs: field length table, OVER flags, consolidated _questions; --questions/--json/--full
  audit_semantic.py     # semantic quality audit of the committed listing: --dispatch / --report / --write-manifest; --min-severity
  merge.py              # tmp/metadata-outputs/{storefront}.json → fastlane/metadata/{storefront}/*.txt + passthrough; deletes fields blank in en-US
  check_metadata.py     # authoritative gate over fastlane/metadata/ (authored fields populated+within limits; blank-source fields have no content)
  PROMPT_TEMPLATE.md    # transcreation prompt template
  AUDIT_PROMPT_TEMPLATE.md # semantic-audit prompt template
  README.md             # this file

.claude/agents/
  metadata-locale.md        # transcreation subagent (Read+Write, model: opus)
  metadata-audit-locale.md  # semantic-audit subagent (Read+Write, model: opus)

tmp/
  metadata-inputs/source.json
  metadata-inputs/manifest.json
  metadata-prompts/{storefront}.md
  metadata-outputs/{storefront}.json
  metadata-audit-prompts/{storefront}.md
  metadata-audit-outputs/{storefront}.json
```
