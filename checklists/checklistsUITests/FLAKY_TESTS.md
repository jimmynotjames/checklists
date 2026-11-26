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
| 2026-11-25 | `checklistCreateUITest/testCreateChecklistAndAddItems` | `checklists/checklistsUITests/checklistCreateUITest.swift:119` | `XCTAssertTrue failed - A Delete in the emptied notes didn't move up to the name.` (failed after 225 s) | CI `ui-tests (editing)` shard (animations off, one retry; 29 others passed), `u/jimmyho/claude-code/clear-flaky-tests-log@619ab43`, CI run 45537014679; no bundle (the job passed, so none was uploaded) | Passed on the shard's own retry (118.5 s); 3/3 passed locally with `TEST_RUNNER_FORCE_ANIMATIONS=off` | The Delete on the emptied notes hands keyboard focus up to the name (`itemContentViewDidBackspaceEmpty`). With animations off on a loaded runner the name may take focus after `waitForKeyboardFocus` gives up, the same kind of focus timing that loses `KeyboardShortcutsUITest`'s shortcuts. The same test also failed at `:112` (notes field didn't hold still to be tapped) on CI run 45508313105, attempt 2 |
| 2026-11-25 | `checklistCreateUITest/testCreateChecklistAndAddItems` | `checklists/checklistsUITests/checklistCreateUITest.swift:114` | `XCTAssertEqual failed` "Text was left in the notes: the caret didn't land at the end." Failed the run and its retry, with different text left each time | CI `ui-tests (editing)` shard (animations off, one retry), `main@fca0723`, CI run 45652655432, [xcresults-ui-tests-editing](https://github.com/jimmynotjames/checklists/actions/runs/45652655432/artifacts/15044224943) | The rerun of the failed jobs (attempt 2) passed | Third sighting of this test. The tap meant to put the caret at the end landed mid-text; `placeCaretAtEnd` now checks where it landed and taps again. The `:112` and `:119` failures above are separate focus timing |
| 2026-11-25 | `AccessibilityAuditUITest/testCreateSheet` | `checklists/checklistsUITests/AccessibilityAuditUITest.swift:242` | First run: `accessibilityAudit` Code=-56 "Audit failed to complete in time". Retry: "The keyboard didn't come up." | CI `ui-tests (accessibility)` shard (animations off, one retry), `main@7c236c2`, CI run 45665326807, [xcresults-ui-tests-accessibility](https://github.com/jimmynotjames/checklists/actions/runs/45665326807/artifacts/15047624910) | The rerun of the failed jobs (attempt 2) passed | A slow runner: the audit's time limit and the keyboard wait both ran out. Not an accessibility finding |
| 2026-11-26 | `AccessibilityAuditUITest/testCreateSheet` | `checklists/checklistsUITests/AccessibilityAuditUITest.swift:243` | The audit timed out (Code=-56), the one-time audit retry then hung, and the runner reported "Lost connection to testmanagerd" and restarted the test process | CI `ui-tests (accessibility)` shard (animations off, one retry), `claude/scheme-test-order@e481c0c`, CI run 45842086428, [xcresults-ui-tests-accessibility](https://github.com/jimmynotjames/checklists/actions/runs/45842086428/artifacts/15131108175) | Rerun of the failed jobs | Second audit timeout on this test (row 2026-11-25 above). The branch changed only the unit-test order; the UI target was untouched |
