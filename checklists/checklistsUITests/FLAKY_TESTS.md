# Flaky tests

Every flaky sighting, UI and unit tests alike, so the flakes can be fixed together once there's
enough data. What counts as flaky and when to log it: AGENTS.md §"Reading a test result".

- **Append only.** Add one row per sighting, even for a test that already has one. A second sighting
  of the same test is the signal worth acting on.
- **Keyboard-key failures get no row.** `kAXErrorCannotComplete` on a keyboard key is a test defect
  to escalate, not a flake: AGENTS.md §"The software keyboard".
- **Committing a row:** a sighting on a feature branch goes in that branch's PR. A sighting on `main`
  stays uncommitted and rides along with the next PR.
- Rows describe what was seen, not how the code got there: `make doc-check` rejects history wording
  in this folder (its patterns are in `scripts/check_doc_pointers.py`).

| Date | Test | File:line | Failure | Run (suite, branch@sha, bundle) | Isolated rerun | Hunch |
|---|---|---|---|---|---|---|
| 2026-10-22 | `ChecklistItemsUITest/testChecklistReordering1` | `checklists/checklistsUITests/ChecklistItemsUITest.swift:140` | XCTAssertTrue failed | `make test-only` class run, u/jimmyho/claude-code/fix-checkboxes-and-reset-test@d5153ec, `tmp/ui-items-class.log` | Passed 3/3 (`ITERATIONS=3`) | Unknown; not investigated |
| 2026-10-22 | `ChecklistItemsUITest/testChecklistReordering1` | `checklists/checklistsUITests/ChecklistItemsUITest.swift:166` | XCTAssertTrue failed | `make test-ui`, u/jimmyho/claude-code/keyboard-done-in-nav-bar@3728746, `tmp/rebase-ui.log` | Passed 3/3 (`ITERATIONS=3`) | Unknown; not investigated |
| 2026-10-22 | `ChecklistItemsUITest/testChecklistReordering1` | `checklists/checklistsUITests/ChecklistItemsUITest.swift:166` | XCTAssertTrue failed | `make test-ui`, u/jimmyho/claude-code/keyboard-done-in-nav-bar@6d2ecfa, `tmp/trail-ui.log` | Passed 3/3 (`ITERATIONS=3`) | Unknown; not investigated |
| 2026-10-22 | `ChecklistOverflowMenuUITest/testCancellingDeleteKeepsTheChecklist` | `checklists/checklistsUITests/ChecklistOverflowMenuUITest.swift:124` | Failed to tap "Cancel" Button: Timed out while synthesizing event | `make test-ui`, u/jimmyho/claude-code/fix-flaky-reorder-test@a3b7c4f+uncommitted, `tmp/reorder1-ui-2.log` | Passed 3/3 (`ITERATIONS=3`) | Simulator load: the run took 1988s against 878s for the run before it |
| 2026-10-23 | `ChecklistCopyCheckedItemsUITest/testCopyCheckedItemsToANamedNewChecklist` | `checklists/checklistsUITests/ChecklistCopyCheckedItemsUITest.swift:117` | Failed to synthesize event: Neither element nor any descendant has keyboard focus | `make test-ui` on a fresh iOS 27.0 simulator (SIMULATOR_UDID), u/jimmyho/claude-code/upgrade-linters@ed2357a+uncommitted, `tmp/test-ui.log` | Passed 3/3 (`ITERATIONS=3`) | Typing before the name field took focus; first UI run on a new simulator |
