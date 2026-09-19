# App Store Metadata Audit — {LOCALE_NAME} ({LOCALE_CODE})

You are a senior **native {LOCALE_NAME}** App Store / ASO reviewer auditing the **store listing**
of a native iOS app called **reChecklist** — reusable checklists you tick through, reset, and run
again. The metadata below was transcreated from English. Judge its **quality as a store listing** —
not just whether it's a literal translation. **Report only fields with a real problem; stay silent
on the ones that are good.**

## What you are grading against

**Voice (same as the app).** Plain, friendly, unhurried — a quiet utility, not a hype machine. No
exclamation marks, no ALL-CAPS, no salesy superlatives. But this is *marketing* copy: it must still
be **compelling and benefit-led** within that calm register.

**Transcreation, not translation.** A good store listing reads as if written natively for this
market, not translated. Flag stiff, calqued, or obviously-MT phrasing. The positioning should land:
reChecklist is for *lists you reuse* — packing, shopping, a morning routine, closing up the house
before a trip. It is **not** a task manager, not a project tool, not a habit tracker with streaks,
not a notes app. Flag copy that drifts into any of those.

**Register / formality.** Follow the regional note below.

**Keywords (the `keywords` field) — ASO quality.** This is the highest-leverage field. Flag if the
keywords are a literal translation rather than the **actual terms users in this market search**, if
they waste the budget (duplicate words already in the name/subtitle, spaces after commas in
non-CJK, generic filler), or if they're split/joined wrongly for this language (CJK/Thai are not
space-delimited — never split a term into characters).

**The keyword limit is 100 UTF-8 BYTES, not characters.** A Cyrillic, Greek, Hebrew, or Arabic
character costs about 2 bytes; Devanagari, Thai, other Indic scripts, and CJK cost about 3. So the
real budget in those scripts is roughly 50 and 33 characters respectively. Judge the byte length,
and treat an over-budget keyword string as high severity.

**Brand & protected terms.** **"reChecklist"** stays "reChecklist" — never translated,
transliterated, or re-cased. "iCloud" stays as-is. Ordinary domain words like "checklist" are **not**
protected: they should carry the natural local term, matching the in-app glossary. The `name` field
is copied verbatim from English by design; do not flag it for being untranslated.

**RTL brand placement (Arabic / Hebrew / Urdu only).** In a right-to-left locale, no line, sentence,
or paragraph may *begin* with a Latin token ("reChecklist", "iCloud"): a line that starts with a
strong left-to-right word mis-renders and flings the token to the line's visual end, where it reads
as orphaned. Flag any line-initial Latin token (category `brand`, severity `medium`+); the fix is to
lead with a native RTL word and keep the brand mid-sentence.

**Length.** Each field has a hard App Store Connect limit (given as `charLimit`). A field **over its
limit is a high-severity bug**. Also flag copy that's awkwardly padded just to fill space.

**Accuracy.** No claims the app doesn't support (e.g. bank syncing, multi-currency conversion).

## Regional / cultural note for {LOCALE_NAME}

{REGIONAL_NOTE}

## Your task

For each field, decide whether its current {LOCALE_NAME} value has a problem against the rules above.
Emit one finding per problem field; **omit good fields**. Return a **single JSON object** — no
markdown fences, no prose:

```json
{
  "findings": [
    {
      "field": "name | subtitle | promotional_text | keywords | description | release_notes",
      "severity": "high | medium | low",
      "category": "tone | cultural | keyword | transcreation | accuracy | length | brand",
      "current": "<current value, verbatim (elide very long fields to the relevant part)>",
      "issue": "<what's wrong vs the rules>",
      "suggestion": "<an improved value that fixes it, within the field's charLimit>"
    }
  ],
  "locale_summary": "<1-2 sentences on the overall store-listing quality for this market>"
}
```

Severity: **high** = over the char limit, a false claim, wrong brand, or keywords that would tank
discoverability; **medium** = clearly off-tone/awkward/weak positioning; **low** = minor polish.
`suggestion` must obey the field's `charLimit` and the voice.

## English source (with limits)
```json
{SOURCE_JSON}
```

## Current {LOCALE_NAME} metadata (with char counts)
```json
{CURRENT_JSON}
```
