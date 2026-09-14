---
name: explore-ux-designs
description: Prototype several visual redesigns of one screen side by side in Xcode's canvas. Generates a gitignored folder of renamed copies of the screen's files, one set per variant, each with its own #Preview, so variants can be compared without editing production code, launching the simulator, or navigating to the screen. Use when asked to explore, compare, or mock up UI/UX options for an existing screen. Also handles cleanup of a previous exploration. Invoked via /explore-ux-designs.
---

# Explore UX designs for a screen

Generates N variants of one screen as **renamed copies** of its source files, each carrying its own
`#Preview`, so the human can flip between them in Xcode's canvas and compare.

**This is scratch work.** Everything generated lives under
`checklists/checklists/DesignExplorations/`, which is gitignored. It is never committed, never
merged, and is deleted when the exploration ends.

**No production file is edited.** Copies own their own `private` members, so there is no need to
loosen access in the real screen. That constraint is what makes this approach worth its rename cost —
if you find yourself wanting to edit a shipping file to make a variant work, you have misunderstood
the design: copy that file into the variant instead.

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

### `ChecklistScreen` file map

| File | Owns visually |
|---|---|
| `Screens/ChecklistScreen.swift` | SwiftUI host: safe-area handling, background colour, the embedded `UINavigationController`, the back button. **Always copy this** — it is the preview's entry point. |
| `ViewControllers/ChecklistViewController.swift` | The screen: table, header layout (status icon / name field / notes), nav-bar buttons, scroll-driven title, keyboard avoidance, drag-reorder. **Almost always copy this.** |
| `Views/ItemContentView.swift` | One item row's interior: checkbox, name, notes, row height animation. Copy for row redesigns. |
| `Views/ItemTableViewCell.swift` | The cell wrapper pinning `ItemContentView` to `contentView`. Copy only if the cell's own constraints change. |
| `Views/CircularPercentStatusIcon.swift` | The circular percent ring (`.header` and `.row` sizes), drawn with `CAShapeLayer`. |
| `Views/CheckboxButton.swift` | The per-item check control. |
| `Views/CLTextField.swift` | The checklist-name field's styling. |
| `Views/CLTextView.swift` | The notes view and its placeholder; also used inside item rows. |
| `Views/AddItemButtonTableFooterView.swift` | The "add item" footer button. |
| `Views/Colors.swift` | Palette. **Do not copy** — to change colours in one variant, set them inline in that variant's own code. Copying the palette makes every variant's diff unreadable. |

For a screen not in this table, derive the set by grepping the screen's file for the custom types it
constructs, then repeat one level down.

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

- `class ChecklistViewController` → `class ChecklistViewControllerCompact`, and each of its eight
  `extension ChecklistViewController: …` blocks.
- `struct ChecklistScreen` → `struct ChecklistScreenCompact`.
- **Protocols, which are easy to miss.** `ItemContentViewDelegate`, `CLTextViewDelegate`, and
  `AddItemButtonTableFooterViewDelegate` are internal top-level declarations. If you copy the file
  declaring one, rename the protocol too — *and* the `extension …: ThatDelegate` conformance in
  whichever other copied file adopts it.

What must **not** be renamed, because file-scope `private` does not collide across files:

- `private let itemsSection`, `itemCellReuseIdentifier`, `defaultChecklistName` at the top of
  `ChecklistViewController.swift`.
- `private struct ChecklistControllerView` in `ChecklistScreen.swift` — but its body still needs
  `ChecklistViewController()` changed to `ChecklistViewControllerCompact()`.

Wrap each generated file in `#if DEBUG` / `#endif`. This is belt-and-braces (the files are
gitignored, so a clean-checkout archive never sees them) but costs two lines.

After renaming, verify nothing was missed:

```bash
grep -rn 'ChecklistViewController\b\|ChecklistScreen\b' checklists/checklists/DesignExplorations/Compact/
```

Every hit should carry the suffix. A bare name is a reference that will bind to the production type —
which compiles silently and then previews the wrong screen. This grep is the main defence against
that.

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

**Non-negotiable.** These files compile into the app target, so a broken variant fails `make build`,
`make gate`, and both test suites until it is fixed or deleted.

```bash
make build 2>&1 | tail -40
```

On a duplicate-symbol error: a top-level type was left unrenamed — re-run the Step 3 grep.
On "cannot find X in scope": a reference was renamed in one copied file but not another.

If a variant cannot be made to build within a couple of attempts, delete that variant, report it
plainly, and deliver the ones that work. Never leave the tree unbuildable.

## Step 7 — Report

Tell the human:

- Which file to open in Xcode for each variant, and that `AllVariants.swift` shows them together.
- What actually differs between the variants, in one line each — the design idea, not the diff.
- That `/explore-ux-designs clean` removes everything when they are done.

Do not claim to have seen the variants render. This skill verifies that they **compile**; the canvas
is the human's surface. If a variant embodies a guess you could not check — a layout that may clip, a
ring size that may collide with the title — say so rather than presenting all three as equally
sound.

## Known limits

- **Compile-only verification.** Nothing here renders a PNG, so visual mistakes reach the human
  unfiltered.
- **Static only.** The canvas cannot show the scroll-driven nav-bar title animation or
  keyboard-avoidance behaviour. Prototyping those needs the running app.
- **Debug build weight** grows while variants exist. Another reason to clean up promptly.
