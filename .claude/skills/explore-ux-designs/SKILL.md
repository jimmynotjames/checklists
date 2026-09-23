---
name: explore-ux-designs
description: "Prototype and compare several visual redesigns of one screen in Xcode's canvas, as gitignored renamed copies each with its own #Preview. Also cleans up a prior exploration."
---

# Explore UX designs for a screen

Generates N variants of one screen as **renamed copies** of its source files, each carrying its own
`#Preview`, so the human can flip between them in Xcode's canvas and compare.

**This is scratch work.** Everything generated lives under
`checklists/checklists/DesignExplorations/`, which is gitignored. It is never committed, never
merged, and is deleted when the exploration ends.

**No production file is edited.** To make a variant work, copy the file into the variant — never
loosen access in a shipping file.

## Invocation

- `/explore-ux-designs <brief>` — e.g. *"three takes on the checklist header: one compact, one with
  the status ring inline, one with notes behind a disclosure"*.
- `/explore-ux-designs clean` — delete the folder and stop.

If the brief names no screen and only one exploration makes sense from context, use
`ChecklistScreen`. If it is genuinely ambiguous which screen is meant, ask before generating.

If the brief does not say how many variants, default to **three**.

---

## Step 1 — Clear any previous exploration

```bash
rm -rf checklists/checklists/DesignExplorations
```

Always start clean. Stale variants from a previous round are the most likely cause of a confusing
duplicate-symbol failure.

For `/explore-ux-designs clean`, run the above, confirm `git status` is clean, and stop here.

## Step 2 — Pick the minimum file set

Copy only the files a variant actually changes. Everything not copied keeps referencing the shared
production type, which is usually what you want.

File map for `ChecklistScreen`: `reference/checklist-screen-files.md`. For a screen not in that
table, derive the set by grepping the screen's file for the custom types it constructs, then
repeat one level down.

## Step 3 — Copy and rename

For each variant, pick a short PascalCase suffix from the brief (`Compact`, `InlineRing`,
`Disclosure`) — not `A`/`B`/`C`, which say nothing in a canvas tab list.

```bash
mkdir -p checklists/checklists/DesignExplorations/Compact
cp checklists/checklists/Screens/ChecklistScreen.swift \
   checklists/checklists/DesignExplorations/Compact/ChecklistScreenCompact.swift
```

Then rename inside each copy. **The rule: every non-private top-level declaration gets the suffix;
every reference to a renamed type within the variant's own files is updated to match.**

What must be renamed:

- `class ChecklistViewController` → `class ChecklistViewControllerCompact`, and every
  `extension ChecklistViewController` block, including those in the copied `+Menu` and `+Strings`
  files.
- `struct ChecklistScreen` → `struct ChecklistScreenCompact`.
- **Protocols, which are easy to miss.** `ItemContentViewDelegate`, `CLTextViewDelegate`, and
  `AddItemButtonTableFooterViewDelegate` are internal top-level declarations. If you copy the file
  declaring one, rename the protocol too — *and* the `extension …: ThatDelegate` conformance in
  whichever other copied file adopts it.

What must **not** be renamed: file-scope `private` declarations (constants at the top of a file,
`private struct ChecklistControllerView` in `ChecklistScreen.swift`), because they don't collide
across files. Their bodies still need renamed references updated, e.g. `ChecklistViewController()`
→ `ChecklistViewControllerCompact()`.

Wrap each generated file in `#if DEBUG` / `#endif`.

After renaming, verify nothing was missed:

```bash
grep -rn 'ChecklistViewController\b\|ChecklistScreen\b' checklists/checklists/DesignExplorations/Compact/
```

Every hit should carry the suffix. A bare name binds to the production type — which compiles
silently and then previews the wrong screen.

## Step 4 — Apply the design change

Now actually implement the brief in each copy. This is the part that is not mechanical; the steps
above only buy the freedom to do it.

Keep variants genuinely distinct. Three near-identical spacing tweaks waste a round — if the brief is
vague, push each variant toward a different idea rather than three points on one axis.

## Step 5 — Previews

Each variant file gets a `#Preview` at the bottom, using the shared fixtures per AGENTS.md ("Don't
build a one-off container or router in a `#Preview`"):

```swift
#if DEBUG
  #Preview("Compact") {
    ChecklistScreenCompact(checklist: PreviewSupport.checklist()) {}
      .previewEnvironment()
  }
#endif
```

`PreviewSupport.checklist()` defaults to the Morning Routine fixture. For a fuller list, pass
`SampleData.preTripId` or `SampleData.weekendGetawayId`.

Then generate `DesignExplorations/AllVariants.swift` for side-by-side comparison — the canvas shows
one `#Preview` at a time, so a combined block is the only way to see them together:

```swift
#if DEBUG
  import SwiftUI

  #Preview("All variants", traits: .fixedLayout(width: 1320, height: 920)) {
    HStack(spacing: 24) {
      ChecklistScreenCompact(checklist: PreviewSupport.checklist()) {}
        .frame(width: 402, height: 874)
      ChecklistScreenInlineRing(checklist: PreviewSupport.checklist()) {}
        .frame(width: 402, height: 874)
    }
    .previewEnvironment()
  }
#endif
```

## Step 6 — Build before reporting

```bash
make build > tmp/build.log 2>&1; echo $?
```

Non-zero means read `tmp/build.log`. These files compile into the app target, so a broken variant
breaks the gate.

On a duplicate-symbol error: a top-level type was left unrenamed — re-run the Step 3 grep.
On "cannot find X in scope": a reference was renamed in one copied file but not another.

If a variant cannot be made to build within a couple of attempts, delete that variant, report it
plainly, and deliver the ones that work. Never leave the tree unbuildable.

## Step 7 — Report

Tell the human:

- Which file to open in Xcode for each variant, and that `AllVariants.swift` shows them together.
- What actually differs between the variants, in one line each — the design idea, not the diff.
- That `/explore-ux-designs clean` removes everything when they are done.

Do not claim to have seen the variants render. This skill verifies only that they **compile** —
nothing here renders a PNG, so visual mistakes reach the human unfiltered on the canvas. If a
variant embodies a guess you could not check — a layout that may clip, a ring size that may
collide with the title — say so rather than presenting all three as equally sound.

## Known limits

- **Static only.** The canvas cannot show the scroll-driven nav-bar title animation or
  keyboard-avoidance behaviour. Prototyping those needs the running app.
- **Debug build weight** grows while variants exist. Another reason to clean up promptly.
