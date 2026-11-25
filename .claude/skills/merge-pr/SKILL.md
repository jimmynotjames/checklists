---
name: merge-pr
description: Wait for a reviewed PR's required CI checks, squash-merge it, delete its branch, and close or annotate any linked issue. Runs no local gate or tests.
---

# Merge a reviewed PR

Use when the user asks to merge an existing, reviewed PR and clean up its branches.
Resolve the requested PR number as `<PR>` below. The user must authorize the merge;
a request to inspect or review a PR alone is not authorization.

1. **Verify it's safe to merge.** Run `gh pr view <PR>` and confirm it is `OPEN` and `MERGEABLE`.

   Wait for the required CI checks (AGENTS.md §"What gates a merge"):

   ```bash
   gh pr checks <PR> --required --watch
   ```

   `tests` is one of them; a docs-only PR's `tests` passes without running anything.

   **If any fails, do NOT merge** — report it and stop. If the latest checks came from a narrowed
   `/ci` run rather than the automatic one, they can read green over a failure (AGENTS.md §CI):
   rerun the automatic run first.

   No local gate or tests: CI runs everything `make gate` does (the `tooling` job covers the
   script and UI-test-source checks) plus the unit and UI suites (AGENTS.md §"Build and test").

2. **Scan the PR body for issue linkage** via `gh pr view <PR> --json body --jq '.body'`: look for
   `Closes #N` (complete fix) or `Refs #N` (partial). If neither is present, this is a no-issue PR
   (e.g. from `/create-pr`) — note that and skip step 5.

3. **Squash-merge:** record the head SHA the green checks ran on
   (`gh pr view <PR> --json headRefOid --jq .headRefOid`), then run
   `gh pr merge <PR> --squash --match-head-commit <SHA>`, so a push after the checks can't land unchecked.
   One PR = one commit on `main`. Never merge on the same turn the PR was opened.

4. **Clean up branches.** The merge does not clean up after itself locally, and may or may not have
   cleaned up the remote:
   - **Remote:** `delete_branch_on_merge` is on, so a 404 from
     `gh api repos/jimmynotjames/checklists/git/refs/heads/<branch>` means success; `-X DELETE`
     only if it still exists.
   - **Local:** `git checkout main && git pull --ff-only && git branch -D <branch>` (`-D`, since a
     squash-merge leaves the local tip un-ancestored)
   - **Stale tracking ref:** `git fetch --prune` (clears the `origin/<branch>` ref that
     `git pull --ff-only` leaves behind)
   - **Simulators:** run `make sim-shutdown` (AGENTS.md §"Simulator slots"). If this checkout is a
     worktree about to be removed, run `make sim-clean` instead (§"Simulator sandbox").

5. **Resolve the linked issue** (skip if step 2 found no issue):
   - **Complete fix** (`Closes #N`) — verify it auto-closed with
     `gh issue view <N> --json state,stateReason`. If still open, close explicitly:
     `gh issue close <N> --comment "Fixed in #<PR>."`
   - **Partial fix** (`Refs #N`) — leave it open and comment a pointer:
     `gh issue comment <N> --body "Partially addressed by #<PR>. Still pending: <summary>."`

6. **Report** what merged, the CI result, that the branch was deleted, that the simulators were shut down, and the final issue state
   (or "no linked issue").
