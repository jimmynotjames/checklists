# Accessibility Spec

> What state each accessibility axis is in, the conventions to follow, and what was decided about
> motion. Keep it terse; detail belongs in the linked PRs and issues.

---

## Status by axis

| Axis | Status | Notes |
| --- | --- | --- |
| **VoiceOver labels/values** | Partial | Every interactive control is labelled; the remaining VoiceOver gaps are **#278**. Checklists, and the items inside a checklist, reorder by Move Up/Down/to Top/to Bottom actions on each row, since neither `.onMove` nor the item table's drag handles and long-press drag offer VoiceOver a way to move a row. On item rows the actions sit on the checkbox and both text views, the elements VoiceOver lands on, and outside Reorder Items mode they add Duplicate and Delete, since the swipe actions belong to the cell. Each item's checkbox reads its status, then the item's name, or "Checkbox" when the name is blank — §Label vs. value |
| **VoiceOver traits** | Partial | `ChecklistHistoryCaption` sets `.staticText`; `ContainerFailureView`'s title and message are one element with `.isHeader`; `MainMenuView` sets `.isModal`, since on a wide window it is a side panel with the list still on screen beside it, and closes on the escape gesture; VoiceOver moves to its Close button when it opens and back to ☰ when it closes. In Reorder Items mode each checkbox is disabled, so it reads as dimmed; everything else relies on platform defaults |
| **Reduce Motion** | Implemented | Every app-authored animation has a recorded verdict — §Animation and Reduce Motion |
| **Dynamic Type** | Implemented | Every screen scales through AX5 with no known layout breaks — §Dynamic Type. Accepted as untested: a live size change on a device, and an AX-size pass in the screenshot audit (it forces xxxLarge). From two steps above the default text size (xxLarge) ChecklistsView's Reset All and Edit mode toolbar collapse to icons, so long translations neither push Edit into an overflow menu nor clip the toolbar; they keep their names for VoiceOver and the Large Content Viewer |
| **Dark Mode** | Not started | The app is locked to Light appearance in `Info.plist` — **#180** |
| **Increase Contrast** | Not started | **#182** |
| **Touch targets (44×44)** | Implemented | `ToastView`, `CopyCheckedItemsView`, `MainMenuView`'s close button, the checklist header's name and notes fields, and each item's name and notes fields enforce a 44pt minimum, and `ChecklistsView`'s last row scrolls clear of the Add button. A toast may sit over rows while it is up, by design: a tap anywhere on it dismisses it |
| **Color-only signaling** | N/A — none | Completion state is an icon swap plus a spoken value, never tint alone |
| **Screen-change announcements** | Partial | `LoadingView` and `ContainerFailureView` post `.screenChanged`; `ToastPresenterModifier` posts announcements; both screens' moves, deletes, duplicates and resets tell VoiceOver what changed — §Announcements and focus |
| **Automated a11y tests** | Not started | No audit-API coverage; UI tests use accessibility attributes only as element hooks |

`UIAccessibility.isVoiceOverRunning` is read by `ToastPresenter`. The other flags
(`isReduceTransparency`, `isBoldTextEnabled`, `shouldDifferentiateWithoutColor`,
`accessibilityViewIsModal`) have **zero call sites**. Assume not handled unless this table says
otherwise.

---

## Conventions

### Two UI stacks, no shared helper

The app is mixed SwiftUI + UIKit (see `AGENTS.md`). There is **no shared accessibility
abstraction** and deliberately so — each stack calls its own platform API:

- SwiftUI: `@Environment(\.accessibilityReduceMotion)`, `.accessibilityLabel(_:)`,
  `.accessibilityElement(children: .combine)`.
- UIKit: `accessibilityLabel` / `accessibilityValue` assignment,
  `UIAccessibility.isReduceMotionEnabled`, `UIAccessibility.post(notification:)`.

Introduce a shared helper only when a third call site needs one; two is not a pattern.

### Label vs. value

State that changes belongs in `accessibilityValue`, not baked into the label — a label that encodes
state gets re-announced wholesale on every change. `CheckboxButton` is the one exception: its
label is "Checked, <item name>" or "Unchecked, <item name>", with no value, because VoiceOver always
reads the label before the value and item names can be long. A listener hears the status first
and can move on after a word or two of the name; a tick re-reads the label, which confirms it. `CircularPercentStatusIcon` goes further and sets
`accessibilityLabel = nil` on purpose, because the percentage *is* the whole announcement — don't
"fix" that nil.

### Dynamic Type

**Checklist screen (UIKit).** Every font is a text style, or a size scaled against one with
`UIFontMetrics`, set with `adjustsFontForContentSizeCategory`, so it rescales live:

| Text | Style |
|---|---|
| Checklist name | 24pt semibold scaled against `.title2`, capped at 45pt (its AX3 size) |
| Checklist notes | `.callout` |
| Item name / notes | `.title2` / `.subheadline` |
| History caption | `.footnote` |

What a font change cannot resize by itself is re-measured on a text-size change: the table's
frame-sized header and footer (`ChecklistViewController`'s trait handler marks them, the next layout
pass measures), the history caption's stated height, the checkbox's line-up with the item name's
first line, and the scroll distance at which the name moves into the navigation bar. Measurements
resolve fonts against the view's own `traitCollection`, never the app-wide size, so trait overrides
and Xcode's canvas see what a user sees. The table replaces its visible cells on a text-size change,
which ends an edit in progress; the typed text is saved as on any other end of editing.

Deliberate exceptions: the name's cap, since the field is one line and longer names truncate;
`CheckboxButton`, which grows with `.title2` to at most 1.25× (60pt) and never below 48pt — from
AX4 up its button configuration enlarges the symbol further on its own, past the frame, which is
accepted: neither turning off the button's accessibility image scaling nor capping its content size
category stops it without shrinking the symbol below its default size; the
header's status ring, which stays 24pt; and fixed margins.

**SwiftUI screens** use semantic font tokens, and their rows wrap rather than truncate. Settings row
icons are SF Symbols, so they grow with their text; the main menu's custom icons stay a fixed size.
`MainMenuView`'s rows scroll under its pinned close button once they outgrow the panel, as the
landscape side panel does at AX5 in long locales. `ToastView` moves an action button under the
message at accessibility sizes, where beside it the message would be left a few letters wide.

`ChecklistRowView` wraps a checklist's name rather than truncating it; its notes stay a three-line
preview. The status ring grows with the name's `.headline` to at most 1.5× (30pt, from AX1), so
it never crowds the name, and stays centred on the name's first line.

`AnalyticsConsentSheet` and `ContainerFailureView` scroll once their content outgrows the screen, so
their buttons stay reachable at every size; the consent sheet's two buttons stay pinned below its
scrolling text.

### Announcements and focus

After an action changes content, VoiceOver gets the two signals a sighted user gets: what changed,
in a few words, and where to carry on. Announcements give a count, never an item's name, which can be
long and which the user just acted on.

- **Focus moves the VoiceOver cursor only** — never the selection or the scroll position — so
  nothing changes on screen when VoiceOver is off. The announcement follows focus after a beat, so
  VoiceOver reading the refocused element doesn't cut it off.
- **After a delete** VoiceOver lands on the row that took the deleted one's place, else the row
  above, else the Add button (`DeletionFocus`).
- **After a duplicate** it stays on the original, as selection does in Photos and Files; the copy is
  the next row down.
- **Checklist screen:** the swipe and VoiceOver Delete, Duplicate, Reset (only when it unticked
  something) and Delete Checked Items (with a count, focus on the first row left) announce. Backspace
  on an empty row doesn't: it moves editing to the row above.
- **Reorder Items mode** swaps the bar item VoiceOver was on, so VoiceOver moves to Done on the way
  in and back to ⋯ on the way out, after the bar has relaid and the ⋯ menu has closed. Tapping the
  Done that typing adds to the bar takes that Done away, so VoiceOver moves to ⋯ then too. The post
  names the `UIBarButtonItem` itself, which VoiceOver resolves to the button the bar draws: the
  bar's own views are private, and in a unit-test host they carry no identifier to find them by.
- **The failure screen** (`ContainerFailureView`) replaces the app unasked, so after a beat it posts
  `.screenChanged` with no string and puts VoiceOver on its title and message, one element, which is
  read once. A string would be read and then the element again. `LoadingView` passes its text as the
  string instead; nothing on it is interactive. A failed Start over fresh leaves the same screen up
  and says nothing new.
- **Checklists list:** a confirmed delete, the swipe Duplicate, Reset All (only when it unticked
  something) and Edit mode's Delete, Duplicate and Reset (with a count) announce. Focus moves after a
  confirmation alert or Edit mode's exit has finished, since the system moves VoiceOver itself as an
  alert closes. After an Edit mode action it goes to Edit, because the bottom toolbar it was on is
  gone; when a delete leaves no checklists it goes to the Add button, since the list has no empty
  state.
- **Rarer outcomes.**
  - The overflow menu's "No checked items." row is announced as it appears; a disabled row isn't read
    out by appearing.
  - When the open checklist is deleted on another device, it closes with a toast saying so, for
    everyone. There's no toast for sample dedupe, whose surviving twin is the same checklist, nor for
    the screen's own Delete Checklist coming back as a store change.
  - The Copy or Move Checked Items sheet closing because nothing is checked any more shows a toast.
  - Settings' iCloud row isn't announced when Checking gives way to a result: VoiceOver reads the
    current value whenever it lands there.

### Identifiers are test hooks

`accessibilityIdentifier` in this tree exists for XCUITest element lookup. It is never read by
VoiceOver and never substitutes for a label.

---

## Animation and Reduce Motion

The app authors almost no custom motion. This table is the record so nobody re-audits by grep —
re-open a row only if that code changes. Dig into **#185** / PR **#186** for the audit method, the
full two-family sweep, and the reasoning behind each verdict.

| Site | Verdict |
| --- | --- |
| `RootView` main-menu transition | **Gated** — cross-fades instead of sliding in from the leading edge |
| `RootView` main-menu scrim (wide windows only) | **Left alone.** Opacity, not simulated movement |
| `ToastPresenterModifier` toast transition | **Gated** — cross-fades instead of sliding up from the bottom edge |
| `ChecklistViewController.resetButtonTapped` scroll-to-top | **Gated** — jumps instead of gliding, and reloads directly, because the animated path defers its reload to `scrollViewDidScroll` |
| `NavigationStack` push/pop, `.sheet`, `.alert`, `Toggle`, `.onMove`, `UIDragInteraction` reorder, `popViewController`/`dismiss` | System-owned. No app code specifies motion |
| `ChecklistViewController` keyboard-inset, item-insert, and scroll-into-view animations (all ≤ 0.1s) | **Functional, left alone.** They keep the edited field clear of the keyboard and the target row on screen; suppressing them trades an a11y win for an a11y regression |
| `ChecklistViewController` row insert/delete/move and row-height reflow | **Left alone.** Ordinary list-editing feedback; Apple's own list apps don't suppress it |
| `ChecklistsView` Edit mode on/off (`withAnimation`) | **Left alone.** The system's own edit-mode reveal of selection circles and handles; Apple's list apps don't suppress it |
| `ChecklistViewController` Reorder Items mode on/off (`setEditing(_:animated:)`, add-item footer fade) | **Left alone.** The system's reveal of drag handles, plus an opacity fade |
| `ChecklistViewController` nav-title fade on scroll | **Left alone.** Opacity, not simulated movement |
| `ChecklistViewController.updateEditingDoneBarButtonItem` editing Done coming and going (`setRightBarButtonItems(_:animated:)`) | **Left alone.** The system's own bar relayout; Notes adds its editing Done the same way |
| `CircularPercentStatusIcon.setInnerCircle`, `CheckboxButton.setCheckboxState` | **Not animated.** Direct property assignment, outside any animation context |
| `ProgressView` spinners (`LoadingView`, `SettingsView`) | System-owned. Progress indicators are not suppressed under Reduce Motion, by Apple's design |

When auditing for new motion, grep two families: the animation APIs **and** the `animated:`
parameter (`setContentOffset`, `scrollToRow`) — UIKit obeys `animated: true` regardless of Reduce
Motion.

---

## Verification

`make gate` proves nothing about accessibility behavior, and the unit tests cover only slices of it,
such as VoiceOver values and the checklist screen's Dynamic Type layout (`ChecklistDynamicTypeTests`).
Real checks are manual, in the simulator:

- VoiceOver: Settings → Accessibility → VoiceOver.
- Reduce Motion / Dynamic Type: Settings → Accessibility → Motion / Display & Text Size.
- Xcode's **Accessibility Inspector** audit is the cheapest broad sweep and is not wired into CI.

State in the PR what you actually toggled.
