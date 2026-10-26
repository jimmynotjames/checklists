# Flaky tests

Every flaky sighting, UI and unit tests alike, so the flakes can be fixed together once there's
enough data. What counts as flaky and when to log it: AGENTS.md §"Reading a test result".

- **Append only.** Add one row per sighting, even for a test that already has one. A second sighting
  of the same test is the signal worth acting on. A test's rows leave only with the change that
  fixes it.
- **Keyboard-key failures get no row.** `kAXErrorCannotComplete` on a keyboard key is a test defect
  to escalate, not a flake: AGENTS.md §"The software keyboard".
- **Committing a row:** a sighting on a feature branch goes in that branch's PR. A sighting on `main`
  stays uncommitted and rides along with the next PR.
- Rows describe what was seen, not how the code got there: `make doc-check` rejects history wording
  in this folder (its patterns are in `scripts/check_doc_pointers.py`).

| Date | Test | File:line | Failure | Run (suite, branch@sha, bundle) | Isolated rerun | Hunch |
|---|---|---|---|---|---|---|
| 2026-10-22 | `ChecklistOverflowMenuUITest/testCancellingDeleteKeepsTheChecklist` | `checklists/checklistsUITests/ChecklistOverflowMenuUITest.swift:124` | Failed to tap "Cancel" Button: Timed out while synthesizing event | `make test-ui`, u/jimmyho/claude-code/fix-flaky-reorder-test@a3b7c4f+uncommitted, `tmp/reorder1-ui-2.log` | Passed 3/3 (`ITERATIONS=3`) | Simulator load: the run took 1988s against 878s for the run before it |
| 2026-10-25 | `AccessibilityAuditUITest/testChecklistEditingItem` | `checklists/checklistsUITests/AccessibilityAuditUITest.swift:109` | Dynamic Type font sizes are partially unsupported, on the last row's checked `CLTextView` ("Sunglasses"), with the keyboard down in the screenshot | `make test-ui`, main@e93b91e, `.build/sim/results/20261025_115831-94278-ui.xcresult` | Passed 3/3 (`ITERATIONS=3`) | The audit's own heuristic under load: a concurrent build had the run at 1642s against 891s, and item text views set `adjustsFontForContentSizeCategory` |
| 2026-10-25 | `AccessibilityAuditDarkUITest/testOverflowMenu` | `checklists/checklistsUITests/AccessibilityAuditUITest.swift:102` | Failed to get matching snapshots: Error getting main window kAXErrorServerNotFound | `make test-ui`, main@e93b91e, `.build/sim/results/20261025_115831-94278-ui.xcresult` | Passed 3/3 (`ITERATIONS=3`) | Simulator load, same run as above; fails at launch, before the test does anything |
| 2026-10-25 | `AccessibilityAuditUITest/testChecklistEditingItem` | `checklists/checklistsUITests/AccessibilityAuditUITest.swift:109` | Dynamic Type font sizes are partially unsupported, on an unchecked `CLTextView` ("Book, iPad, Kindle..."); the keyboard was on screen before the audit, and its screenshot shows editing ended | `make test-ui`, u/jimmyho/claude-code/keep-sim-keyboard-on-screen@b19a01e+uncommitted, `.build/sim/results/20261025_231611-2969-ui.xcresult` | Passed 3/3 (`ITERATIONS=3`) | The audit ends the edit it was meant to inspect, then flags a row mid-relayout; not the hidden keyboard |
