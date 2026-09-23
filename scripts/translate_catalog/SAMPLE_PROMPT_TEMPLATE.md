# Transcreation task — demo checklists for {LOCALE_NAME} ({LOCALE_CODE})

You are localizing the **demo content** of **reChecklist**, a native iOS app for reusable checklists (a list you tick through, reset, and run again). The strings below are the three sample checklists every new install starts with (a morning routine, a weekend-trip packing list, and a leaving-the-house-before-a-trip list), and the App Store screenshots show them too. They are the first thing a person in {LOCALE_NAME} sees.

This is **transcreation, not translation**. The test for every item: *would a person living where {LOCALE_NAME} is spoken actually write this on their own list?* If not, replace it with what they would write.

## Rules

1. **Make every item culturally native.**
   - Swap items foreign to daily life there for the local equivalent. If a coffee maker is not the everyday morning ritual, it becomes a tea kettle, a moka pot, a rice cooker: whatever is true. "Argue politics on Facebook" keeps its wry, self-aware tone but names the network people there actually argue on. "Post office: hold mail" becomes what a local does about mail before a trip, or a different pre-trip errand if that service doesn't exist. "Turn off heater or A/C" follows the local climate. "Wallet/ID" notes reflect the documents a local carries.
   - Keep genuinely universal items (phone charger, toiletries, lock doors and windows); just render them naturally.
   - Never invent brand names. Use a real, widely known local name or a generic noun.
   - The morning-routine item in ALL CAPS is a deliberate quirk of a hand-written list; keep an equivalent emphasis if the script has one, otherwise plain case.
2. **The structure is fixed.** Every input key maps to exactly one output string. Don't merge, split, add, or drop items; the count, the order, and which items read as "done" in the screenshots are fixed by the keys. A note (`*.notes` key) stays a note for the same item; adapt it to match your item.
3. **Keep names short.** These are one-line rows in a narrow phone list. `enChars` is the English length: a soft budget. Prefer the shortest natural phrasing; a name that wraps is worse than one that loses a detail. Notes may run a little longer.
4. **Use the `comment` field** for what the item is and which list it belongs to.
5. **Voice.** Plain, friendly, everyday: the way a real person writes a list for themselves, in the register the regional note sets. No marketing tone, no exclamation marks.
6. **Protected names.** "reChecklist" and "iCloud" stay verbatim if they appear; Apple product names stay as Apple writes them in {LOCALE_NAME}. Keep any format specifier (`%@`, `%lld`) exactly.
7. **If a string is genuinely impossible to adapt,** copy the English and add a `"<key>__note"` sibling saying why.

## Regional note for {LOCALE_NAME}

{REGIONAL_NOTE}

<!-- if glossary -->
## Glossary: agreed {LOCALE_NAME} terms

Where a demo item uses one of these app terms, render it with the agreed translation.

{GLOSSARY}
<!-- end glossary -->

## Output

One JSON object mapping every input key to its {LOCALE_NAME} string, with no fences and no prose.

## Source strings

```json
{SOURCE_JSON}
```
