# Accessibility Spec

| Field        | Value      |
| ------------ | ---------- |
| Version      | 1.0        |
| Last Updated | 2026-09-13 |
| Author/Owner | Jimmy Ho   |

> Canonical per-axis accessibility status for this app, written to be **read instead of
> re-derived**. If you are about to grep the tree for `accessibilityLabel` or
> `isReduceMotionEnabled` to find out where things stand, read this first. Where this document and
> the code disagree, one of them is a bug — say which in the PR.
>
> Deliberately terse. Detail lives in the linked PRs and issues, not here. Keep it that way:
> a doc that costs more tokens than the grep it replaces has failed at its only job.
>
> Umbrella tracking issue **#142** is the live list of open accessibility work — read it there,
> not here.

---

## 1. Status by axis

| Axis | Status | Where |
| --- | --- | --- |
| **VoiceOver labels/values** | Partial | `CheckboxButton`, `ItemContentView`, `ChecklistViewController`, `AnalyticsConsentSheet` |
| **VoiceOver traits** | Not started | No `accessibilityTraits` anywhere; everything relies on default SwiftUI/UIKit traits |
| **Reduce Motion** | Implemented | Two sites: `RootView` (menu transition) and `ChecklistViewController` (Reset scroll). Full inventory and verdicts in §3 |
| **Dynamic Type** | Partial | SwiftUI uses semantic tokens (`ChecklistRowView`); UIKit hardcodes point sizes — §2.3. Issue **#183** |
| **Dark Mode** | Not started | Forced off: `Info.plist` `UIUserInterfaceStyle = Light` (since `cc1bba2`). Issue **#180** |
| **Increase Contrast** | Not started | No `isDarkerSystemColorsEnabled` call site. Issue **#182** |
| **Touch targets (44×44)** | Not started | Issue **#184** |
| **Color-only signaling** | N/A — none | Completion is an icon swap plus `accessibilityValue`, not tint alone (`CheckboxButton`) |
| **Screen-change announcements** | Partial | One call site: `LoadingView` (`UIAccessibility.post(.screenChanged:)`) |
| **Automated a11y tests** | Not started | No `performAccessibilityAudit`; UI tests use `accessibilityIdentifier`/`accessibilityValue` as element hooks only |

Other `UIAccessibility` flags (`isVoiceOverRunning`, `isReduceTransparency`, `isBoldTextEnabled`,
`shouldDifferentiateWithoutColor`, `accessibilityViewIsModal`) have **zero call sites**. Assume not
handled unless this table says otherwise.

---

## 2. Conventions

### 2.1 Two UI stacks, no shared helper

The app is mixed SwiftUI + UIKit (see `.claude/CLAUDE.md` and the SwiftUI conversion work). There is
**no shared accessibility abstraction** and deliberately so — each stack calls its own platform API:

- SwiftUI: `@Environment(\.accessibilityReduceMotion)`, `.accessibilityLabel(_:)`,
  `.accessibilityElement(children: .combine)`.
- UIKit: `accessibilityLabel` / `accessibilityValue` assignment,
  `UIAccessibility.isReduceMotionEnabled`, `UIAccessibility.post(notification:)`.

Introduce a shared helper only when a third call site actually needs one; two call sites is not a
pattern.

### 2.2 Label vs. value

State that changes belongs in `accessibilityValue`, not baked into the label — a label that encodes
state gets re-announced wholesale on every change. `CheckboxButton` sets a static label once and
swaps only the value (`Checked`/`Unchecked`). `CircularPercentStatusIcon` goes further and sets
`accessibilityLabel = nil` on purpose, because the percentage *is* the whole announcement — don't
"fix" that nil.

### 2.3 Dynamic Type

SwiftUI screens use semantic font tokens and scale for free. UIKit views do **not**: they hardcode
point sizes with no `adjustsFontForContentSizeCategory` (zero hits repo-wide). Known offenders —
`ItemContentView` and `ChecklistViewController` (`CLTextView`'s hardcoded size is a fallback only
reached when no caller sets `.font`). Fixed frames worth watching at large sizes: the FAB in
`ChecklistsView` (60×60), `MainMenuView`'s close button (44×44), `CheckboxButton` (48×48). Tracked
by **#183**; don't fix piecemeal in unrelated PRs.

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

- VoiceOver: Settings → Accessibility → VoiceOver (or ⌘-click the status item in Accessibility Inspector).
- Reduce Motion / Dynamic Type: Settings → Accessibility → Motion / Display & Text Size.
- Xcode's **Accessibility Inspector** audit is the cheapest broad sweep and is not wired into CI.

State in the PR what you actually toggled.

---

## 5. Change log

Links only — read the PR, not a summary of it.

| When | Ref | What |
| --- | --- | --- |
| 2026-09-13 | #185 | Reduce Motion for the main-menu transition and the Reset scroll-to-top; this document; the animation decision table in §3 |
| 2026-09-12 | #175 | Checklist row progress exposed as an `accessibilityValue` |
| 2021-03-04 | `392301b`, `83c808c` | Percent-complete icon announcement reworded; label dropped in favor of value |
| 2020-02-05 | `cc1bba2` | Locked the app to Light appearance (the reason Dark Mode is "not started") |
| 2020-02-01 | `cd00b94`, `78042b9`, `2f1a8e6` | Original pass: checklist fields and checkbox states, checklists + main menu controls, and toast announcements on the since-removed Donate screen (#122) |
