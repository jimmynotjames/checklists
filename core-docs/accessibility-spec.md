# Accessibility Spec

> What state each accessibility axis is in, the conventions to follow, and what was decided about
> motion. Read it instead of re-deriving; where it and the code disagree, one is a bug — say which
> in the PR. It gives status, not call sites: to find where something lives, grep.
>
> Keep it terse. Detail belongs in the linked PRs and issues, and **#142** is the live list of open
> work.

---

## 1. Status by axis

| Axis | Status | Notes |
| --- | --- | --- |
| **VoiceOver labels/values** | Partial | Most interactive controls are labelled; the reordering gap and the remaining unlabelled controls are **#181** |
| **VoiceOver traits** | Not started | No traits set anywhere; everything relies on platform defaults |
| **Reduce Motion** | Implemented | Every app-authored animation has a recorded verdict — §3 |
| **Dynamic Type** | Partial | SwiftUI scales via semantic tokens; UIKit hardcodes point sizes — §2.3, **#183** |
| **Dark Mode** | Not started | The app is locked to Light appearance in `Info.plist` — **#180** |
| **Increase Contrast** | Not started | **#182** |
| **Touch targets (44×44)** | Not started | **#184** |
| **Color-only signaling** | N/A — none | Completion state is an icon swap plus a spoken value, never tint alone |
| **Screen-change announcements** | Partial | One screen announces its state change; the rest don't |
| **Automated a11y tests** | Not started | No audit-API coverage; UI tests use accessibility attributes only as element hooks |

Other `UIAccessibility` flags (`isVoiceOverRunning`, `isReduceTransparency`, `isBoldTextEnabled`,
`shouldDifferentiateWithoutColor`, `accessibilityViewIsModal`) have **zero call sites**. Assume not
handled unless this table says otherwise.

---

## 2. Conventions

### 2.1 Two UI stacks, no shared helper

The app is mixed SwiftUI + UIKit (see `AGENTS.md` and the SwiftUI conversion work). There is
**no shared accessibility abstraction** and deliberately so — each stack calls its own platform API:

- SwiftUI: `@Environment(\.accessibilityReduceMotion)`, `.accessibilityLabel(_:)`,
  `.accessibilityElement(children: .combine)`.
- UIKit: `accessibilityLabel` / `accessibilityValue` assignment,
  `UIAccessibility.isReduceMotionEnabled`, `UIAccessibility.post(notification:)`.

Introduce a shared helper only when a third call site needs one; two is not a pattern.

### 2.2 Label vs. value

State that changes belongs in `accessibilityValue`, not baked into the label — a label that encodes
state gets re-announced wholesale on every change. `CheckboxButton` sets a static label once and
swaps only the value (`Checked`/`Unchecked`). `CircularPercentStatusIcon` goes further and sets
`accessibilityLabel = nil` on purpose, because the percentage *is* the whole announcement — don't
"fix" that nil.

### 2.3 Dynamic Type

SwiftUI screens use semantic font tokens and scale for free. UIKit views do **not**: they hardcode
point sizes with no `adjustsFontForContentSizeCategory` (zero hits repo-wide). Known offenders —
`ItemContentView` and `ChecklistInfoHeaderView` (`CLTextView`'s hardcoded size is a fallback only
reached when no caller sets `.font`). Fixed frames worth watching at large sizes: the FAB in
`ChecklistsView` (60×60), `MainMenuView`'s close button (44×44), `CheckboxButton` (48×48), and the
checklist screen's history caption, whose height is stated rather than intrinsic because the table
header is measured once from constraints (`ChecklistHistoryCaption.height`). Tracked by **#183**;
don't fix piecemeal in unrelated PRs.

### 2.4 Identifiers are test hooks, not accessibility

`accessibilityIdentifier` in this tree exists for XCUITest element lookup. It is never read by
VoiceOver and never substitutes for a label.

---

## 3. Animation inventory and Reduce Motion decisions

The app authors almost no custom motion. This table is the record so nobody re-audits by grep —
re-open a row only if that code changes. Dig into **#185** / PR **#186** for the audit method, the
full two-family sweep, and the reasoning behind each verdict.

| Site | Verdict |
| --- | --- |
| `RootView` main-menu transition | **Gated** — cross-fades instead of sliding in from the leading edge |
| `ToastPresenterModifier` toast transition | **Gated** — cross-fades instead of sliding up from the bottom edge |
| `ChecklistViewController.resetButtonTapped` scroll-to-top | **Gated** — jumps instead of gliding, and reloads directly, because the animated path defers its reload to `scrollViewDidScroll` |
| `NavigationStack` push/pop, `.sheet`, `.popover`, `.alert`, `Toggle`, `.onMove`, `UIDragInteraction` reorder, `popViewController`/`dismiss` | System-owned. No app code specifies motion |
| `ChecklistViewController` keyboard-inset, item-insert, and scroll-into-view animations (all ≤ 0.1s) | **Functional, left alone.** They keep the edited field clear of the keyboard and the target row on screen; suppressing them trades an a11y win for an a11y regression |
| `ChecklistViewController` row insert/delete/move and row-height reflow | **Left alone.** Ordinary list-editing feedback; Apple's own list apps don't suppress it |
| `ChecklistViewController` nav-title fade on scroll | **Left alone.** Opacity, not simulated movement |
| `CircularPercentStatusIcon.setInnerCircle`, `CheckboxButton.setCheckboxState` | **Not animated.** Direct property assignment, outside any animation context |
| `ProgressView` spinners (`LoadingView`, `SettingsView`) | System-owned. Progress indicators are not suppressed under Reduce Motion, by Apple's design |

When auditing for new motion, grep two families: the animation APIs **and** the `animated:`
parameter (`setContentOffset`, `scrollToRow`) — UIKit obeys `animated: true` regardless of Reduce
Motion, and missing that family is how the Reset scroll escaped the first pass.

---

## 4. Verification

Neither `make gate` nor the test suites prove anything about accessibility behavior. Real checks are
manual, in the simulator:

- VoiceOver: Settings → Accessibility → VoiceOver.
- Reduce Motion / Dynamic Type: Settings → Accessibility → Motion / Display & Text Size.
- Xcode's **Accessibility Inspector** audit is the cheapest broad sweep and is not wired into CI.

State in the PR what you actually toggled.

---

## 5. Change log

Links only — read the PR, not a summary of it.

| When | Ref | What |
| --- | --- | --- |
| 2021-03-04 | `392301b`, `83c808c` | Percent-complete icon announcement reworded; label dropped in favor of value |
| 2020-02-05 | `cc1bba2` | Locked the app to Light appearance (the reason Dark Mode is "not started") |
| 2020-02-01 | `cd00b94`, `78042b9`, `2f1a8e6` | Original pass: checklist fields and checkbox states, checklists + main menu controls, and toast announcements on the since-removed Donate screen (#122) |
