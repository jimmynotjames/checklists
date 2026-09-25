# Flaky tests

A test is flaky when it fails in a full run and then passes when rerun on its own. This file collects
every sighting, UI and unit tests alike, so the flakes can be fixed together once there's enough
data. How to spot one and rerun it: the "Reading a test result" section of `AGENTS.md`.

- **Append only.** Add one row per sighting, even for a test that already has one. A second sighting
  of the same test is the signal worth acting on.
- **Don't fix a flake in passing.** Log it and name it in your report; fixes happen as their own
  batch.
- **Take `file:line` from the `TEST-FAILED:` lines** the test scripts print, never from a guess.
- **Keyboard failures count too.** A run that prints `SIM-KEYBOARD-FLAKE tests-failed` gets a row
  with that tag in the failure column.
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
