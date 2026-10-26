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
| 2026-10-26 | `checklistsUITests/testChecklistReordering` | `checklists/checklistsUITests/checklistsUITests.swift:93` | Row 1 should have moved below row 2 (row 1 at y 131.8, row 2 at y 183.8): the rows never moved | `make test-ui` with `UI_WORKERS=3`, u/jimmyho/claude-code/copy-sheet-settle@912bea4+uncommitted, `.build/sim/results/20261026_110142-81504-ui.xcresult` | Failed 1/3 (`ITERATIONS=3`) | Not load alone, since it failed in isolation too: the long press never lifted the row. It is the first touch after launch |
