# Localization Spec

> How this app gets into 50 languages and stays there: the key convention, the locale registry, the
> four pipelines, and the gates that hold them. Keep it terse; the per-pipeline detail belongs in
> each pipeline's own README and skill.

---

## Status

| Surface | State |
| --- | --- |
| **In-app strings** | 50 locales (English source + 49), fully translated, audited |
| **First-launch sample data** | Localized through the catalog, transcreated per locale |
| **App Store listing** | 49 storefronts transcreated; `name` and URLs copied from English |
| **Screenshot seeds** | Generated for all 50 from the catalog |
| **Screenshot capture** | All 50 active; a full run is release-time work |
| **Plurals** | Plural variants in the catalog where a count is shown (`pluralize_keys.py`) |
| **Display name** | `reChecklist` verbatim everywhere; no `InfoPlist.xcstrings` |

---

## Key convention

Every user-facing string is a dotted key in
`checklists/checklists/Localizable.xcstrings`, read through
`String(localized:defaultValue:comment:)`:

```swift
String(
  localized: "checklist.progress.accessibilityValue",
  defaultValue: "Checklist \(percent) complete",
  comment: "VoiceOver value for the progress ring. The argument is an already-formatted percentage."
)
```

Rules:

- **Keys are `screen.purpose.detail`.** `common.*` is only for copy that is genuinely identical
  across surfaces, not for copy that merely happens to match today.
- **The translator comment is mandatory.** A translator sees the string and the comment, never the
  screen. A comment that repeats the English is worse than none, because it looks done.
- **Locale-invariant text uses `Text(verbatim:)`.** An empty navigation title or an alert with no
  title is not a translatable string, and `Text("")` gets re-extracted into the catalog on every
  IDE build.
- **Never hand-edit the catalog.** It is generated. Use the scripts in
  `scripts/translate_catalog/` — `add_keys.py`, `rename_keys.py`, `remove_keys.py`,
  `invalidate_keys.py`, `pluralize_keys.py`.
- **Formatting is locale-aware by construction.** Dates go through `DateFormatter`, percentages
  through `.formatted(.percent)`. Never interpolate a number and a symbol by hand.
- **A key that only makes sense next to another is declared as a pair.** "Discard" sits beside
  "Cancel" on one alert; in eight languages the natural word for discard *is* the word for cancel,
  and a translator who sees one key at a time cannot know they will meet. Name the neighbour in the
  translator comment, and add the pair to `DISTINCT_PAIRS` in
  `scripts/translate_audit/distinct_pairs.py` so the gate fails if a locale ever collapses them.

### Strings that are also data

`checklist.defaultName` and the `sample.*` namespace are written into the persistent store at
creation time. Switching language later does not rename existing records, by design: a user's own
data is theirs, not a view of the catalog. The call sites carry this in their comments.

---

## Locale registry

`fastlane/screenshot-config.json` `locales[]` is the single source of truth: 50 rows of
`{runtime, storefront, region, name}`. Everything else derives from it.

- `scripts/translate_catalog/locales.py` reads it and exposes the runtime set, the display names,
  and the runtime/storefront maps. It raises at import if a row is malformed or a code is duplicated.
- `scripts/translate_metadata/metadata_locales.py` imports those maps rather than keeping its own,
  and takes Apple's field limits from `scripts/appstore_metadata.py`, the validator that actually
  gates the upload. There is one statement of those limits in the repo.
- `scripts/tests/test_locale_registry.py` pins `fastlane/metadata-locales.json` and
  `appstore_metadata.FASTLANE_LOCALES` to the registry; `check_metadata.py` re-asserts it at runtime.

Runtime codes are the catalog's codes (`de`, `nb`, `zh-Hans`). Storefront codes are Apple's
(`de-DE`, `no`, `zh-Hans`). They differ often enough that mixing them is the most common mistake in
this area.

---

## The four pipelines

Each is a set of scripts plus a skill; the skill is the entry point.

| Pipeline | Skill | What it does |
| --- | --- | --- |
| `scripts/translate_catalog/` | `translate-new-strings` | Translates new or changed catalog keys, one subagent per locale |
| `scripts/translate_audit/` | `audit-translations` | Grades existing translations for tone, register, length, accuracy |
| `scripts/translate_metadata/` | `appstore-translate-metadata` | Transcreates the App Store listing per storefront |
| `scripts/screenshot_content/` | `appstore-generate-screenshot-seeding` | Regenerates the screenshot seeds from the catalog |

All four follow the same shape: extract what is missing, compose one prompt per locale, fan out one
subagent per locale, validate, merge. Outputs land in `tmp/`, never in the repo, until the merge step
writes them.

### Models are pinned deliberately

Sonnet translates ordinary UI strings. Opus does the glossary, the audits, the App Store metadata, and
the `sample.*` transcreation. The agent definitions pin this by alias (`sonnet`, `opus`), so each
agent moves to the newest model in its tier on release; that is deliberate. A new model behind
an alias is not a reason to regenerate: existing strings stay until an audit flags them or a
systemic prompt or rule change invalidates them. The current baseline is the October 2026 full
pass (glossary, every UI and `sample.*` string, then a full audit) on Sonnet 5.5 and Opus 5.5. Every agent runs at
`effort: medium`, which is enough from Opus 5.5 on; do not raise it. Do not "upgrade" a translation
agent to Opus for a routine string run, and do not downgrade a transcreation agent to save time.

The `sample.*` and App Store listing audits are Opus checking Opus, an exception to the rule that the
auditor out-classes the producer: a higher tier costs more than that small, re-audited copy warrants.
Read those audits as a consistency pass, not a senior review.

### Transcreation vs translation

The `sample.*` namespace and the App Store listing are **transcreated**: the brief is what a local
would write, not what the English says. A locale's morning routine opens with a tea kettle where
English opens with a coffee maker, and the social-network joke swaps to whichever network is
dominant there. Structure is preserved exactly — same item count, same order, same items reading as
done — because the screenshot seeds and the parity check depend on it.

The glossary (`scripts/translate_catalog/glossary.json`) keeps recurring terms consistent across
locales and protects `reChecklist` and `iCloud` from being translated.

### Register

The principle every locale's form of address follows:

> The voice is modern and respectful: current and unfussy, never stiff or old-fashioned, and never
> so casual that it would sound flippant to an older reader. Use the informal address where people
> of every generation would expect it from a modern app, and the polite form where that is still
> the respectful norm.

Audience age is not the test: the reader might be anyone's grandmother, and the app speaks to her
the way a well-made mainstream app in her language does.

The call is made **once per locale, by Opus**, and written into that locale's note (see below) as
the concrete form (*vous*, *vy*, 해요체) plus where warmth comes from instead. Translators follow the
note; they never re-decide it string by string, which is how a locale ends up mixing both forms.
The recurring failure is system text (error messages, Settings footers, VoiceOver hints) drifting
formal, so the prompts name it. Short button labels are exempt: they keep the glossary's form.

The `sample.*` lists are the exception: they are someone's own notes to self, so nobody is being
addressed and the note's form of address doesn't apply.

---

## Running the pipelines

- **Clean `tmp/` between runs** with `scripts/pipeline_tmp.py clean <group>`. The merge step reads
  every file in an outputs dir, so a stale `tmp/translate-outputs/de.json` from a previous run
  merges silently: last week's translation with this week's keys.
- **The per-locale notes are duplicated on purpose.** `REGIONAL_NOTES` in
  `translate_catalog/dispatch_prompts.py` and `CULTURAL_NOTES` in
  `translate_metadata/dispatch_prompts.py` are separate because in-app and marketing register are
  different decisions — not a DRY violation to fix. But change a locale's formality call in both, or
  the app and its listing address the same person two different ways.
- **No ad-hoc Python.** Every step, inspection included, is a flag on a pipeline script. Reaching
  for `python3 -c` or a throwaway `tmp/*.py` means a script is missing a flag: extend the script, so
  the permission surface stays narrow and the next run gets the primitive too.
- **Fan out in batches, agents only.** Send about 8–12 agent calls per message with
  `run_in_background: true`, and never put a `Bash` call in the same message. One failed call
  cancels its whole batch, in-flight agents included. Never `nohup`, never a shell loop that blocks
  the session. On a tool without a subagent primitive, run the step inline and serially: read each
  prompt file, produce the JSON yourself, write the matching output file. Same scripts, same gates,
  same result.

---

## Screenshot seeds

The seed catalogs under `checklists/checklistsUITests/ScreenshotSeeds/` are **generated, never
authored**: `en-US.json` gives the structure and the catalog's `sample.*` keys give the words. Since
those are the same keys the app uses on first launch, a screenshot shows exactly what a new user
sees.

The join runs English value → key → translation, never localized text to localized text: the
namespace is transcreated, so the localized strings are deliberately not parallel to the English.

`generate_seeds.py --check` runs in `make uitest-check`, so a change to the sample strings that
leaves the seeds stale fails the gate. Editing a seed file by hand is therefore pointless — the gate
checks the seeds against the catalog.

Adding or changing a sample item means: edit `SampleData.swift` and the matching catalog key, re-run
the transcreation fan-out, then `generate_seeds.py`.

---

## Gates

| Check | Where | Blocking |
| --- | --- | --- |
| `check_translations.py` | `make i18n-check`, pre-push, CI | Yes |
| `check_source_strings.py` | `make i18n-check`, pre-push, CI | Yes |
| `generate_seeds.py --check` | `make uitest-check` | Yes |
| `check_metadata.py` | CI, `push_metadata` lane | Yes |
| `plural_completeness.py` | CI | Yes |
| `untranslated_copies.py` | CI | Yes |
| `distinct_pairs.py` | `make i18n-check`, CI | Yes |
| `consistency_check.py` | CI | No, informational |
| `check_source_voice.py` | `push_metadata` lane | No, advisory |
| `check_content.py` | Screenshot lanes | Yes |

`check_source_strings.py` is the one that catches the common mistake: a bare `Text("English")` added
to a view, or a pair of capitalized literals in a ternary parked in a local before they reach a UI
call. It is a gate failure, not a review note.

`distinct_pairs.py` catches the mistake no reviewer can see in a diff: two strings that share a
screen and read identically in some locale.

---

## Large-type layout check

`scripts/translation-accessibility-size-check/` drives 13 locales through its screens at forced
`.xxxLarge` and leaves the screenshots for reading. It asserts nothing — the reading is the check —
and it is deliberately outside the app test suites and `make gate`. Findings go in its `AUDIT_LOG.md`.

The checklist detail screen is UIKit with fixed fonts and does not scale with Dynamic Type. See
`accessibility-spec.md §Dynamic Type` and issue #183.

---

## Known gaps

- `ChecklistScreen.swift` hardcodes `edgeSwipe.edges = .left`, which is the wrong edge under
  right-to-left layout.
- The accessibility labels in `ItemContentView.swift` and `ChecklistInfoHeaderView.swift` carry a
  trailing `": "` inside the localized value, which reads oddly and makes the string harder to
  translate well.
- `DesignExplorations/` compiles into the app target, so literals there can be re-extracted into the
  catalog by an IDE build. `check_source_strings.py` skips the directory.
