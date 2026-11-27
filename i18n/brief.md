# reChecklist localization brief

App-specific prose for the shared prompt templates under scripts/translate_*/. Each fragment
fills the template placeholder of the same name; scripts/translate_catalog/app_config.py loads
them. A fragment may use the template's own placeholders ({LOCALE_NAME}) and {APP_NAME}.

## translate_catalog/PROMPT_TEMPLATE.md

<!-- fragment UI_INTRO -->
Translate the UI strings of **reChecklist**, a native iOS app, from English into **{LOCALE_NAME}**. reChecklist keeps reusable checklists: a list you tick through, reset, and run again (morning routine, packing, pre-trip). It is a quiet utility, not a task manager or habit tracker.
<!-- end UI_INTRO -->

<!-- fragment UI_VOICE -->
Match Apple's first-party iOS voice for {LOCALE_NAME}, carrying this app's character: plain, friendly, unhurried; "a clean sheet of paper", not a productivity dashboard. The traits stay constant; express them the way {LOCALE_NAME} naturally does. Quiet warmth is welcome, hype is not, and warmth comes from word choice, never from extra words or punctuation. No exclamation marks, no ALL-CAPS, no salesy superlatives, no celebrating routine actions (ticking an item, resetting a list). Never gamify or scold: no streak, trophy or "great job!" framing, no guilt about unfinished lists.
<!-- end UI_VOICE -->

<!-- fragment UI_PROTECTED_RULE -->
"reChecklist" stays exactly "reChecklist": never translated, transliterated, or re-cased. Leave "iCloud" and other proper nouns Apple keeps in English in its own UI. Domain nouns like "Checklist" are not protected; translate them.
<!-- end UI_PROTECTED_RULE -->

<!-- fragment GLOSSARY_COMPOSE_EXAMPLE -->
for "Delete Checklist", reuse "Delete" and "Checklist"
<!-- end GLOSSARY_COMPOSE_EXAMPLE -->

## translate_catalog/SAMPLE_PROMPT_TEMPLATE.md

<!-- fragment SAMPLE_SUBJECT -->
demo checklists
<!-- end SAMPLE_SUBJECT -->

<!-- fragment SAMPLE_INTRO -->
You are localizing the **demo content** of **reChecklist**, a native iOS app for reusable checklists (a list you tick through, reset, and run again). The strings below are the three sample checklists every new install starts with (a morning routine, a weekend-trip packing list, and a leaving-the-house-before-a-trip list), and the App Store screenshots show them too. They are the first thing a person in {LOCALE_NAME} sees.
<!-- end SAMPLE_INTRO -->

<!-- fragment SAMPLE_ITEMS_RULE -->
   - Swap items foreign to daily life there for the local equivalent. If a coffee maker is not the everyday morning ritual, it becomes a tea kettle, a moka pot, a rice cooker: whatever is true. "Argue politics on Facebook" keeps its wry, self-aware tone but names the network people there actually argue on. "Post office: hold mail" becomes what a local does about mail before a trip, or a different pre-trip errand if that service doesn't exist. "Turn off heater or A/C" follows the local climate. "Wallet/ID" notes reflect the documents a local carries.
   - Keep genuinely universal items (phone charger, toiletries, lock doors and windows); just render them naturally.
   - Never invent brand names. Use a real, widely known local name or a generic noun.
   - The morning-routine item in ALL CAPS is a deliberate quirk of a hand-written list; keep an equivalent emphasis if the script has one, otherwise plain case.
<!-- end SAMPLE_ITEMS_RULE -->

## translate_catalog/GLOSSARY_TRANSLATE_PROMPT.md

<!-- fragment GLOSSARY_APP_LINE -->
**reChecklist**, a native iOS app for
reusable checklists.
<!-- end GLOSSARY_APP_LINE -->

<!-- fragment GLOSSARY_COMPOSE_RULE -->
Some terms combine ("Reset" + "All" → "Reset All")
<!-- end GLOSSARY_COMPOSE_RULE -->

<!-- fragment GLOSSARY_VOICE -->
reChecklist's voice is plain, friendly, and unhurried — a quiet
   utility, no hype, no exclamation marks.
<!-- end GLOSSARY_VOICE -->

<!-- fragment GLOSSARY_PROTECTED_EXAMPLE -->
(e.g. "reChecklist" stays "reChecklist", "iCloud" stays "iCloud")
<!-- end GLOSSARY_PROTECTED_EXAMPLE -->

<!-- fragment GLOSSARY_OUTPUT_EXAMPLE -->
{ "Reset All": "<translation>", "Reset": "<translation>", "Checklist": "<translation>", "reChecklist": "reChecklist" }
<!-- end GLOSSARY_OUTPUT_EXAMPLE -->

## translate_catalog/GLOSSARY_CURATION_PROMPT.md

<!-- fragment CURATION_INTRO -->
# Glossary curation — pick the canonical term set for reChecklist

You are a senior localization architect for **reChecklist**, a native iOS app for reusable
checklists (a list you tick through, reset, and run again). Before the app's UI strings are
translated into 49 languages, we want a **glossary**: a focused set of recurring terms that must
translate **consistently** everywhere they appear, so two buttons that both say "Reset" never
drift apart, and so a compound like "Reset All" can reuse the agreed translation of "Reset".
<!-- end CURATION_INTRO -->

<!-- fragment CURATION_INCLUDE -->
- **Exact repeated strings** — any English string used under more than one key (e.g. "Cancel",
  "Delete", "Settings", "Notes"). These must be identical wherever they appear. Include
  essentially all of these.
- **Core domain nouns** — the app's vocabulary: "Checklist", "Item", "Notes", "Name", etc. These
  should read the same in every screen.
- **High-frequency action verbs** that pair with those nouns — "Add", "Delete", "Reset", "Done",
  "Cancel" — so compounds ("Reset All", "Add new checklist") compose from a stable base.
- **Recurring feature names** — "iCloud Sync", "Privacy Policy", "Send Feedback", "Version".
<!-- end CURATION_INCLUDE -->

<!-- fragment CURATION_EXCLUDE -->
**Exclude**: full sentences, accessibility hints, one-off phrasings, the demo checklist content
under `sample.*` keys (that content is transcreated per locale, not pinned), and generic connective
words that don't carry app meaning. Aim for a **focused set (~15–30 terms)**, not every token.
Quality and reusability over coverage. Prefer the shortest meaningful term: pin "Reset" and "All"
only if each recurs; pin the phrase "Reset All" only if the phrase itself recurs and benefits from a
single canonical form.
<!-- end CURATION_EXCLUDE -->

<!-- fragment CURATION_PROTECTED -->
These are **never translated** — include them as terms so downstream steps lock them, with context
noting they stay verbatim: see `protected` in the candidates JSON (e.g. **reChecklist**, **iCloud**).
(Domain nouns such as **Checklist** are ordinary glossary terms — translate them per locale; they
are not protected.)
<!-- end CURATION_PROTECTED -->

<!-- fragment CURATION_OUTPUT_EXAMPLE -->
    {
      "en": "Reset All",
      "context": "Menu action and confirmation button that unchecks every item in every checklist — clears progress, never deletes lists.",
      "partOfSpeech": "verb phrase",
      "sourceKeys": ["checklists.action.resetAll"]
    },
    {
      "en": "Reset",
      "context": "Imperative action verb: uncheck every item in one checklist so it can be run again. Should compose cleanly ('Reset All').",
      "partOfSpeech": "verb",
      "sourceKeys": ["..."]
    }
<!-- end CURATION_OUTPUT_EXAMPLE -->

<!-- fragment CURATION_CONTEXT_EXAMPLE -->
(e.g. "Cancel" = dismiss
  a sheet, not cancel a subscription; "Reset" = uncheck items, not factory-reset)
<!-- end CURATION_CONTEXT_EXAMPLE -->

## translate_audit/AUDIT_PROMPT_TEMPLATE.md

<!-- fragment AUDIT_APP_LINE -->
**reChecklist**, a native iOS app for reusable checklists you tick through, reset, and run again.
<!-- end AUDIT_APP_LINE -->

<!-- fragment AUDIT_VOICE -->
Plain, friendly, unhurried: a tidy utility that stays out of the way, "a clean sheet of paper", not a productivity dashboard. Quiet warmth is welcome, hype is not, and warmth comes from word choice, never from extra words or punctuation. No exclamation marks, no ALL-CAPS, no salesy superlatives, no celebrating routine actions. Never gamify or scold: no streak, trophy or "great job!" framing, no guilt about unfinished lists.
<!-- end AUDIT_VOICE -->

<!-- fragment AUDIT_BRAND -->
"reChecklist" and "iCloud" stay as-is: not translated, transliterated, or re-cased. Domain nouns such as "Checklist" are translated; flag one left in English.
<!-- end AUDIT_BRAND -->

<!-- fragment AUDIT_SAMPLE -->
**Demo content (`sample.*` keys).** These are the three demo checklists a new install starts with, also shown in the App Store screenshots. They are transcreated, so the test is "would a local actually write this on their own list?", not fidelity to the English. Grade them on cultural fit (`category: cultural`): a coffee maker left where tea is the morning norm, a foreign social network, a postal or climate reference that doesn't apply here. Don't flag a `sample.*` string merely for departing from the English; that departure is the point. The structure is fixed, so never suggest merging, splitting, adding, or dropping an item. The lists are someone's own notes to self, so the regional note's form of address doesn't apply: grade an item's verb form by whether a local would write it that way on their own list, never by the note's address.
<!-- end AUDIT_SAMPLE -->

<!-- fragment GLOSSARY_INLINE_EXAMPLE -->
(the "Reset" in "Reset All")
<!-- end GLOSSARY_INLINE_EXAMPLE -->

## translate_metadata/PROMPT_TEMPLATE.md

<!-- fragment STORE_APP_LINE -->
**reChecklist**, a native iOS app for **reusable checklists**: lists you tick through, reset, and run again.
<!-- end STORE_APP_LINE -->

<!-- fragment STORE_VOICE -->
A **quiet, dependable utility**: you write a list once, and it is there every time you need it again. **Plain, friendly, unhurried**; a clean sheet of paper, not a productivity dashboard.

- **Calm and understated:** never hype; no exclamation marks, ALL-CAPS, or salesy superlatives ("the best", "amazing", "revolutionary").
- **Never gamify or scold:** no streaks, trophies, or pressure to finish. An unfinished list is not a failure.
- **Concrete:** name real lists people keep (packing, shopping, a morning routine, a pre-trip sweep of the house); the concrete example makes the category click.
- **Short and scannable:** lead with the benefit (never forget a step; run the same list again), not the mechanism.
<!-- end STORE_VOICE -->

<!-- fragment STORE_BRIEF -->
1. **Reuse: the list doesn't disappear when you finish it.** Tick it through, reset it, run it again. The hero message; a plain to-do app throws the list away.
2. **Never forget a crucial step:** the tenth time you pack or close up the house, nothing is missed because the list remembers.
3. **Learning a routine:** run a new or complex sequence until it is second nature.
4. **Everyday breadth:** packing, shopping, work routines, leaving the house before a trip. Ordinary lists, not project management.
5. **Quiet and simple:** no accounts to configure, no system to adopt. It syncs across your devices through iCloud.
<!-- end STORE_BRIEF -->

<!-- fragment STORE_NOT -->
**reChecklist is not** (never imply it): a task manager, project tool, or team collaboration app; a habit tracker with streaks, scores, or daily-goal pressure; a note-taking or document app; a calendar or reminder-with-alerts app.
<!-- end STORE_NOT -->

<!-- fragment STORE_SCREENSHOTS -->
**The two screenshots beside the text are already said:** the checklists overview (everyday lists with progress rings) and one pre-trip list part-way ticked. Don't spend scarce characters re-describing them unless the point is worth landing in both words and pictures (the reuse hero is); stress what a picture can't convey, like a list that is ready again or the breadth of uses. This picks which existing copy to emphasize; it is not license to add claims the English doesn't make.
<!-- end STORE_SCREENSHOTS -->

<!-- fragment STORE_BRAND_RULE -->
1. **Brand.** "reChecklist" is the product's name: never translate, transliterate, explain, or gloss its "re-" prefix. Its casing is fixed (lowercase "re", capital "C"), even in a header, for emphasis, or against local title-casing.
<!-- end STORE_BRAND_RULE -->

<!-- fragment STORE_EXTRA_RULES -->

<!-- end STORE_EXTRA_RULES -->

<!-- fragment STORE_APPLE_TERMS -->
5. **Apple terms.** Leave "iCloud" and other proper nouns Apple keeps in English in its own UI. Domain words like "checklist" are not protected: translate them, using the agreed term below wherever one is given.
<!-- end STORE_APPLE_TERMS -->

<!-- fragment STORE_GLOSSARY -->
The app's own {LOCALE_NAME} interface names its core concept with these words. Someone who reads the listing and then opens the app must meet the same word, so these renderings override your own preference, a more searchable synonym, and any loanword hint in the market note:

{GLOSSARY}

- **Use the agreed word for every mention** in `subtitle`, `promotional_text`, `description` and `release_notes`, in whatever plural, case, article or compound form the sentence needs, and in this language's casing (a common noun stays lowercase mid-sentence, whatever the label casing above). A different word or synonym is wrong, and so is swapping between the local word and the English loanword (in either direction) or writing English "checklist" in Latin script where the agreed word isn't that.
- **A shorter form only where this language would naturally use one.** In a longer field, a later mention may shorten the agreed term, much as English prose shortens "checklist" to "list", but only when native copy here really does that and the meaning stays unmistakable. Never shorten in `subtitle`, and never shorten to a different word.
- **The agreed word must be searchable.** Put its base form in `keywords` unless `name` or `subtitle` already has that exact form (the Keywords section's same-form rule; a plural in the subtitle still leaves the base form a slot). The Roman-script English "checklist" may also appear as an extra search term, but never in place of the agreed word, and never a synonym in its place.
<!-- end STORE_GLOSSARY -->

<!-- fragment STORE_SUBTITLE -->
It sits directly under this storefront's app name, **{STORE_NAME}** (fixed; not yours to change), so don't repeat the name's words. The 30-character `subtitle` is tight: a clean, punchy line that fits beats a literal one that doesn't. Lead with **reuse/repeatability**, as the English does, even when a lower-priority benefit translates more neatly. People read it and search indexes it, so it must work as both. Two habits spoil it:
- **Calquing "reusable":** many languages reserve their formal "reusable" adjective for physical goods (bags, containers); on a list it reads oddly and earns nothing in search. Say the reuse idea as people say it here, even as a short phrase.
- **Dropping the category:** pure modifiers with no word for *checklist* or *list* leave the strongest indexed field nothing to match. Fit the category term in unless that makes the line unnatural.
<!-- end STORE_SUBTITLE -->

<!-- fragment STORE_KEYWORD_DOMAIN -->
`keywords` are search terms, not prose: what a native {LOCALE_NAME} user would type to find a checklist or packing-list app. Comma-separated, **no spaces after commas**, deduplicated; singular forms are usually enough. Don't translate the English list one for one: drop terms nobody searches here, add the local high-volume ones, and include the forms people really type, common English loanwords and accepted abbreviations included.

**Two coverage requirements the byte budget doesn't excuse** (the most common failure in this field; a list that misses them is wrong however well sized):
- **Reuse must be searchable:** at least one term for *repeat / reuse / recurring / again* as locals phrase it. Generic list-and-packing words alone describe a category shared with dozens of apps.
- **The category head noun must be reachable:** "checklist" or "list" as this market searches it, often the local word *and* the Roman-script English loanword where both are typed. Bare modifiers match nothing.

**Don't spend the budget on the anti-positioning above.** *To-do*, *task*, *chore*, or *habit* pull the listing toward task managers and habit trackers, in the most crowded queries. Use one only when it is genuinely how locals name a checklist. When tight, a to-do term is the first cut and a reuse term the last.
<!-- end STORE_KEYWORD_DOMAIN -->

<!-- fragment STORE_UNBUNDLE_EXAMPLE -->
"packing list" wastes a byte on the space and blocks recombination; `packing,list` still forms the phrase
<!-- end STORE_UNBUNDLE_EXAMPLE -->

<!-- fragment STORE_EXAMPLE_LISTS -->
Examples in the source (packing lists, shopping lists, work routines…) are illustrations, not fixed copy: swap in the lists a local reader keeps, replace one that isn't salient here with a comparable everyday one, and drop to three if only three ring true. Keep them concrete and ordinary, and the sentence natural.
<!-- end STORE_EXAMPLE_LISTS -->

## translate_metadata/AUDIT_PROMPT_TEMPLATE.md

<!-- fragment STORE_AUDIT_APP_LINE -->
**reChecklist**, a native iOS app for reusable checklists you tick through, reset, and run again.
<!-- end STORE_AUDIT_APP_LINE -->

<!-- fragment STORE_AUDIT_VOICE -->
Plain, friendly, unhurried: a quiet utility, not a hype machine. No exclamation marks, no ALL-CAPS, no salesy superlatives. It is still marketing copy, so it must be compelling and benefit-led within that calm register.
<!-- end STORE_AUDIT_VOICE -->

<!-- fragment STORE_AUDIT_POSITIONING -->
The positioning must land: reChecklist is for lists you reuse (packing, shopping, a morning routine, closing up the house before a trip). It is not a task manager, a project tool, a habit tracker with streaks, or a notes app; flag copy that drifts into any of those.
<!-- end STORE_AUDIT_POSITIONING -->

<!-- fragment STORE_AUDIT_BRAND -->
"reChecklist" stays "reChecklist": never translated, transliterated, or re-cased. "iCloud" stays as-is. Domain words like "checklist" are not protected, but where an agreed term is given below they must use it.
<!-- end STORE_AUDIT_BRAND -->

<!-- fragment STORE_AUDIT_GLOSSARY -->
Flag (`category: terminology`, severity `medium`) any field that renders the term with a different word or synonym, swaps between the local word and the English loanword, or writes English "checklist" in Latin script where the agreed word isn't that. Required plural, case, article or compound forms of the agreed word are correct. In a longer field, a later shortened mention is fine only where native copy here really would shorten it and the meaning stays clear; a shortened `subtitle` is a finding. The agreed word must be searchable: its base form belongs in `keywords` unless the name or subtitle already has that exact form (then repeating it is wasted budget, not a requirement). `keywords` may also add the Roman-script "checklist" as an extra term, never in place of the agreed word. Use the agreed word in your `suggestion`.
<!-- end STORE_AUDIT_GLOSSARY -->

<!-- fragment STORE_AUDIT_RTL_TOKENS -->
("reChecklist", "iCloud")
<!-- end STORE_AUDIT_RTL_TOKENS -->

<!-- fragment STORE_AUDIT_CLAIMS -->
such as reminders or alerts, sharing lists with other people, or streaks and goals
<!-- end STORE_AUDIT_CLAIMS -->
