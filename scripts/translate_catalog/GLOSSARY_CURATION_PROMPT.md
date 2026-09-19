# Glossary curation — pick the canonical term set for reChecklist

You are a senior localization architect for **reChecklist**, a native iOS app for reusable
checklists (a list you tick through, reset, and run again). Before the app's UI strings are
translated into 49 languages, we want a **glossary**: a focused set of recurring terms that must
translate **consistently** everywhere they appear, so two buttons that both say "Reset" never
drift apart, and so a compound like "Reset All" can reuse the agreed translation of "Reset".

Your job: from the candidate data and the full string inventory below, **curate the term set** —
choose the terms worth pinning, and for each write a short context note and part of speech.
**Do not translate anything** — that happens in a later step.

## What makes a good glossary term

Include a term when **consistency across the app matters** for it:
- **Exact repeated strings** — any English string used under more than one key (e.g. "Cancel",
  "Delete", "Settings", "Notes"). These must be identical wherever they appear. Include
  essentially all of these.
- **Core domain nouns** — the app's vocabulary: "Checklist", "Item", "Notes", "Name", etc. These
  should read the same in every screen.
- **High-frequency action verbs** that pair with those nouns — "Add", "Delete", "Reset", "Done",
  "Cancel" — so compounds ("Reset All", "Add new checklist") compose from a stable base.
- **Recurring feature names** — "iCloud Sync", "Privacy Policy", "Send Feedback", "Version".

**Exclude**: full sentences, accessibility hints, one-off phrasings, the demo checklist content
under `sample.*` keys (that content is transcreated per locale, not pinned), and generic connective
words that don't carry app meaning. Aim for a **focused set (~15–30 terms)**, not every token.
Quality and reusability over coverage. Prefer the shortest meaningful term: pin "Reset" and "All"
only if each recurs; pin the phrase "Reset All" only if the phrase itself recurs and benefits from a
single canonical form.

## Protected nouns (include them, mark them clearly)

These are **never translated** — include them as terms so downstream steps lock them, with context
noting they stay verbatim: see `protected` in the candidates JSON (e.g. **reChecklist**, **iCloud**).
(Domain nouns such as **Checklist** are ordinary glossary terms — translate them per locale; they
are not protected.)

## Inputs

### Candidate signals (duplicate strings + frequent words)
```json
{CANDIDATES_JSON}
```

### Full string inventory (key → English → comment) for context
```json
{STRING_INVENTORY_JSON}
```

## Output

Write a **single JSON object** (no markdown fences, no prose) to `{TERMS_OUT_PATH}`:

```json
{
  "terms": [
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
  ]
}
```

- `context` must be specific enough that a translator picks the right sense (e.g. "Cancel" = dismiss
  a sheet, not cancel a subscription; "Reset" = uncheck items, not factory-reset). Pull meaning from
  the `comment` fields and surrounding keys.
- For **ambiguous terms**, spell out the exact meaning and call out false-cognate traps, so the
  disambiguation survives into translation. Choose the unambiguous local term for each.
- `sourceKeys` should list the keys where the term appears (copy from the candidate data; for a
  sub-word term like "Add", list a few representative keys).
- Output **only** the JSON object, written to the path above.
