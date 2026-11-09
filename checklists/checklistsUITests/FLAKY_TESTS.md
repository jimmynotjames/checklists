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
| 2026-11-08 | `ChecklistCopyCheckedItemsUITest/testDestinationJustAboveKeyboardTakesTapWhileTyping` | `checklists/checklistsUITests/ChecklistCopyCheckedItemsUITest.swift:207` | `XCTAssertTrue failed - The create sheet's name field never took focus.` (`openCreateSheet`, in the setup loop that adds five checklists) | Full UI suite on CI (`make test-ui`, 2 workers, iPhone 17; 78 others passed), `u/jimmyho/claude-code/duo-split-view@7dd55f3`, CI run 42556554437 artifact `20261109_033402-16560-ui.xcresult` | 5/5 passed (`ITERATIONS=5`, local) | Five create sheets opened back to back on a loaded 2-worker CI runner: one sheet's name field took longer than `waitForKeyboardFocus`'s 10 s to take focus, or the Add tap landed while the previous sheet was still dismissing |
| 2026-11-08 | `checklistCreateUITest/testCreateBlankChecklist` | `checklists/checklistsUITests/checklistCreateUITest.swift:241` | `XCTAssertTrue failed - The create sheet's name field never took focus.` (`openCreateSheet`, the test's first step) | Full UI suite on CI (`make test-ui`, 2 workers, iPhone 17; 78 others passed), `u/jimmyho/claude-code/duo-split-view@0363582`, CI run 42564796367 artifact `20261109_050701-15976-ui.xcresult` | 5/5 passed (`ITERATIONS=5`, local) | Same `openCreateSheet` focus wait as the row above, on the next CI run of the same branch: two sightings in two CI runs, none locally. Either the 10 s wait is too short for a loaded CI runner, or the create sheet presented over `RootView`'s `NavigationSplitView` reaches `viewDidAppear` (where the name field takes focus) late or not at all |
