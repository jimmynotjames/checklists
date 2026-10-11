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
| 2026-09-23 | `ChecklistCopyCheckedItemsUITest/testCopyCheckedItemsEntryExplainsItselfWithNothingChecked()` | `ChecklistCopyCheckedItemsUITest.swift:172` | XCTAssertTrue failed - The notice didn't appear. | UI, `icloud-sync-instrumentation` (PR 247), `20260923_070853-ui` | 3/3 passed | The notice shows for 2 s (`ChecklistViewController+Menu.swift`), and the first check lands at about 1.8 s. |
| 2026-09-23 | `checklistCreateUITest/testCreateBlankChecklist()` | `checklistCreateUITest.swift:235` | XCTAssertTrue failed | UI, `main@4cf229c`, `20260923_093109-ui` | 3/3 passed | Done is tapped while the new-checklist sheet is still opening. |
| 2026-09-25 | `ChecklistCopyCheckedItemsUITest/testCopyCheckedItemsEntryExplainsItselfWithNothingChecked()` | `ChecklistCopyCheckedItemsUITest.swift:172` | XCTAssertTrue failed - The notice didn't appear. | UI, `checkbox-button-configuration@1d19056`, `20260925_130231-ui` | 2/2 passed | Same as above. |
| 2026-09-25 | `checklistCreateUITest/testCreateBlankChecklist()` | `checklistCreateUITest.swift:235` | XCTAssertTrue failed | UI, `checkbox-button-configuration@1d19056`, `20260925_130231-ui` | 2/2 passed | Same as above. |
| 2026-10-04 | `checklistCreateUITest/testCreateBlankChecklist()` | `checklistCreateUITest.swift:235` | XCTAssertTrue failed | UI, `main@13a6fe5`, `20261004_084812-99457-ui` | 2/3 passed (failed at `:235`) | Same as above. |
| 2026-10-09 | `checklistUITest/testNewItemStaysAboveKeyboardInLandscape()` | `checklistUITest.swift:570` | XCTAssertTrue failed | UI, `u/jimmyho/claude-code/delete-move-checked-items`, `20261009_220516-9955-ui` | 2/3 passed on the branch; 3/5 passed on `main@9096d6a` | The Morning Routine tap lands while the rotation to landscape is still settling, so the push never happens. |
| 2026-10-11 | `checklistUITest/testNewItemStaysAboveKeyboardInLandscape()` | `checklistUITest.swift:570` | XCTAssertTrue failed | UI with 2 parallel clones, `u/jimmyho/claude-code/simulator-slots`, `20261011_123335-24999-ui` | 3/3 passed on `u/jimmyho/claude-code/split-checklist-ui-test` | Same as above. |
| 2026-10-11 | `ChecklistAddItemsUITest/testNewItemStaysAboveKeyboardInLandscape()` | `ChecklistAddItemsUITest.swift:136` | XCTAssertTrue failed | UI with 2 parallel clones, `split-checklist-ui-test@17ac0be` stacked on `simulator-slots@204410a`, `20261011_145713-39261-ui` | 3/3 passed | Same as above. |
