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
