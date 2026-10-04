# Accessibility Spec

> What state each accessibility axis is in, the conventions to follow, and what was decided about
> motion. Keep it terse; detail belongs in the linked PRs and issues.

---

## Status by axis

| Axis | Status | Notes |
| --- | --- | --- |
| **VoiceOver labels/values** | Partial | Most interactive controls are labelled; the remaining unlabelled controls are **#181**. Checklists, and the items inside a checklist, reorder by Move Up/Down/to Top/to Bottom actions on each row, since neither `.onMove` nor the item table's drag handles and long-press drag offer VoiceOver a way to move a row. On item rows the actions sit on the checkbox and both text views, the elements VoiceOver lands on |
| **VoiceOver traits** | Partial | `ChecklistHistoryCaption` sets `.staticText`; `MainMenuView` sets `.isModal`, since on a wide window it is a side panel with the list still on screen beside it; everything else relies on platform defaults |
| **Reduce Motion** | Implemented | Every app-authored animation has a recorded verdict — §Animation and Reduce Motion |
| **Dynamic Type** | Partial | SwiftUI scales via semantic tokens; UIKit hardcodes point sizes — §Dynamic Type, **#183**. From two steps above the default text size (xxLarge) the list's Reset All and Edit mode toolbar collapse to icons, so long translations neither push Edit into an overflow menu nor clip the toolbar; they keep their names for VoiceOver and the Large Content Viewer |
| **Dark Mode** | Not started | The app is locked to Light appearance in `Info.plist` — **#180** |
| **Increase Contrast** | Not started | **#182** |
| **Touch targets (44×44)** | Partial | `ToastView` and `CopyCheckedItemsView` enforce a 44pt minimum; the rest is **#184** |
| **Color-only signaling** | N/A — none | Completion state is an icon swap plus a spoken value, never tint alone |
| **Screen-change announcements** | Partial | `LoadingView` posts `.screenChanged`; `ToastPresenterModifier` and both screens' move actions post announcements; nothing else does |
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
state gets re-announced wholesale on every change. `CheckboxButton` sets a static label once and
swaps only the value (`Checked`/`Unchecked`). `CircularPercentStatusIcon` goes further and sets
`accessibilityLabel = nil` on purpose, because the percentage *is* the whole announcement — don't
"fix" that nil.

### Dynamic Type

SwiftUI screens use semantic font tokens and scale for free. UIKit views do **not**: they hardcode
point sizes with no `adjustsFontForContentSizeCategory` (zero hits repo-wide). Known offenders —
`ItemContentView` and `ChecklistInfoHeaderView` (`CLTextView`'s hardcoded size is a fallback only
reached when no caller sets `.font`). Fixed frames worth watching at large sizes: the FAB in
`ChecklistsView` (60×60), `MainMenuView`'s row icons (44×44), `CheckboxButton` (48×48), and the
checklist screen's history caption, whose height is stated rather than intrinsic because the table
header is measured once from constraints (`ChecklistHistoryCaption.height`). Tracked by **#183**;
don't fix piecemeal in unrelated PRs.

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
| `CircularPercentStatusIcon.setInnerCircle`, `CheckboxButton.setCheckboxState` | **Not animated.** Direct property assignment, outside any animation context |
| `ProgressView` spinners (`LoadingView`, `SettingsView`) | System-owned. Progress indicators are not suppressed under Reduce Motion, by Apple's design |

When auditing for new motion, grep two families: the animation APIs **and** the `animated:`
parameter (`setContentOffset`, `scrollToRow`) — UIKit obeys `animated: true` regardless of Reduce
Motion.

---

## Verification

Neither `make gate` nor the test suites prove anything about accessibility behavior. Real checks are
manual, in the simulator:

- VoiceOver: Settings → Accessibility → VoiceOver.
- Reduce Motion / Dynamic Type: Settings → Accessibility → Motion / Display & Text Size.
- Xcode's **Accessibility Inspector** audit is the cheapest broad sweep and is not wired into CI.

State in the PR what you actually toggled.
