# Translation task — {LOCALE_NAME} ({LOCALE_CODE})

Translate the UI strings of **reChecklist**, a native iOS app, from English into **{LOCALE_NAME}**. reChecklist keeps reusable checklists: a list you tick through, reset, and run again (morning routine, packing, pre-trip). It is a quiet utility, not a task manager or habit tracker.

## Rules

1. **Format specifiers.** `%@` is a runtime value (a name, a date), `%1$@` and `%2$@` are positional, `%lld` is an integer count. Keep every specifier verbatim, in the same count and form as the source; their order may change if {LOCALE_NAME} grammar needs it (`%1$@, %2$@` → `%2$@, %1$@`). Numbers and dates are formatted at runtime.
2. **Context.** Each entry's `comment` says where the string appears and what it means. A short label like "Cancel" is a dismiss button, not "cancel a subscription".
3. **Voice.** Match Apple's first-party iOS voice for {LOCALE_NAME}, carrying this app's character: plain, friendly, unhurried; "a clean sheet of paper", not a productivity dashboard. The traits stay constant; express them the way {LOCALE_NAME} naturally does. Quiet warmth is welcome, hype is not, and warmth comes from word choice, never from extra words or punctuation. No exclamation marks, no ALL-CAPS, no salesy superlatives, no celebrating routine actions (ticking an item, resetting a list). Never gamify or scold: no streak, trophy or "great job!" framing, no guilt about unfinished lists.
4. **Register.** Follow the regional note below. Where it doesn't settle formality, use the informal address only if modern, youth-oriented consumer-app copy in {LOCALE_NAME} uses it; if the language keeps the polite form in app copy regardless of audience age, keep it. Forced informality reads as wrong, not friendly.
5. **Length.** These are terse strings in tight layouts. `enChars` is the English length: treat it as a soft budget. Use the shortest natural phrasing that keeps the meaning and the tone, and don't pad for warmth or politeness. Run longer only where {LOCALE_NAME} structurally needs it (compounding, agglutination, script width).
6. **Native, not translated.** Use this language's punctuation conventions, not English ones (no trailing period on a short button label). Render the idea in a natural idiom rather than a word-for-word calque, and restructure English clause order where that reads better.
7. **Protected names.** "reChecklist" stays exactly "reChecklist": never translated, transliterated, or re-cased. Leave "iCloud" and other proper nouns Apple keeps in English in its own UI. Domain nouns like "Checklist" are not protected; translate them.
8. **Every input key appears in the output.** If a string is genuinely untranslatable (rare), copy the English and add a `"<key>__note"` sibling saying why.

<!-- if plural -->
## Plurals

An entry with a `plural` object instead of `value` is count-dependent. Map its key to a JSON object of CLDR categories → strings, e.g. `"key": {"one": "…", "other": "…"}`.
- If the entry has `requiredPluralCategories`, produce **exactly** those categories, no fewer and no extra: it is the authoritative CLDR set {LOCALE_NAME} needs for integer counts. Without the list, use the categories {LOCALE_NAME} needs, which may differ from English. Always include `other`. Valid: `zero`, `one`, `two`, `few`, `many`, `other`.
- Keep `%lld` in every category, and get each category's grammar right (agreement, word endings).
<!-- end plural -->

## Regional note for {LOCALE_NAME}

{REGIONAL_NOTE}

<!-- if glossary -->
## Glossary: agreed {LOCALE_NAME} terms

Render these terms exactly as listed so they read identically across the app, including inside a longer string: for "Delete Checklist", reuse "Delete" and "Checklist". If the whole string is a glossary term, use that entry. Coherence wins: if stitching terms together reads awkwardly or ungrammatically, write the natural rendering and keep the key terms recognizable.

{GLOSSARY}
<!-- end glossary -->

## Output

One JSON object mapping each key to its translation (a string, or a category object for a plural), with no fences and no prose.

## Source strings

```json
{SOURCE_JSON}
```
