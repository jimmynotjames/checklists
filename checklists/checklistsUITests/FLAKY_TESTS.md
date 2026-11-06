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
| 2026-11-05 | `ChecklistItemsUITest/testChecklistEditItemName` | `checklists/checklistsUITests/ChecklistItemsUITest.swift:141` | `XCTAssertTrue failed`: the name read after 11 delete-key presses didn't equal the original minus its last 11 characters | `ChecklistItemsUITest` (8 tests), `u/jimmyho/claude-code/checklist-screen-context-menu@6461faa`, `.build/sim/results/20261105_181140-36475-only.xcresult` | 3/3 passed (`ITERATIONS=3`) | The value is read straight after the key presses with no wait, so it may catch the field mid-update; or the tap at (0.9, 0.9) left the cursor short of the end |
