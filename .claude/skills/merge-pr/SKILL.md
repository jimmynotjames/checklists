---
name: merge-pr
description: After review, verify the branch with a local gate run, squash-merge a PR, delete its branch, and close or annotate any linked issue. Works with PRs opened by /create-pr-for-issue (issue-linked) and /create-pr (no issue required).
---

# Merge a reviewed PR

Use when the user asks to merge an existing, reviewed PR and clean up its branches.
Resolve the requested PR number as `<PR>` below. The user must authorize the merge;
a request to inspect or review a PR alone is not authorization.

1. **Verify it's safe to merge.** Run `gh pr view <PR>` and confirm it is `OPEN` and `MERGEABLE`.

   Then **gate the branch locally** — this is the only real safety check that exists here. `main` has
   branch protection, but it requires **zero status checks and zero approvals**, and
   `.github/workflows/ci.yml` is **disabled**, so `gh pr merge` would happily land a branch that
   doesn't compile:

   ```bash
   gh pr checkout <PR>
   make gate
   ```

   Run the gate asynchronously with the current tool’s background/session mechanism and
   collect its final exit status; it logs to `tmp/gate.log`. **If the
   gate fails, do NOT merge** — report the failure and stop. If the gate produced formatting or lint
   fixes, commit and push them to the PR branch before merging (they belong in this PR, not a
   follow-up).

   > **When CI is enabled** (uncomment the triggers in `ci.yml` and add the jobs as required
   > checks): replace the local gate here with `gh pr checks <PR> --watch`, run in the background —
   > never a hand-rolled sleep loop — and keep `make gate` as the fallback for anything CI doesn't
   > cover. See AGENTS.md §"What gates a merge".

2. **Scan the PR body for issue linkage** via `gh pr view <PR> --json body --jq '.body'`: look for
   `Closes #N` (complete fix) or `Refs #N` (partial). If neither is present, this is a no-issue PR
   (e.g. from `/create-pr`) — note that and skip step 5.

3. **Squash-merge:** record the validated PR head SHA, verify it still matches the local
   tested commit, then run `gh pr merge <PR> --squash --match-head-commit <SHA>`.
   One PR = one commit on `main`. Never merge on the same turn the PR was opened.

4. **Clean up branches.** The merge does not clean up after itself locally, and may or may not have
   cleaned up the remote:
   - **Remote — usually already gone.** This repo has `delete_branch_on_merge` enabled, so GitHub
     deletes the head branch as part of the merge. Check first:
     `gh api repos/jimmynotjames/checklists/git/refs/heads/<branch>`. A **404 means it is already
     deleted — that is the expected result, not a failure.** Only if the ref still exists, delete it:
     `gh api repos/jimmynotjames/checklists/git/refs/heads/<branch> -X DELETE`.
   - **Local:** `git checkout main && git pull --ff-only && git branch -D <branch>` (`-D`, since a
     squash-merge leaves the local tip un-ancestored)
   - **Stale tracking ref:** `git fetch --prune` (clears the `origin/<branch>` ref that
     `git pull --ff-only` leaves behind)

5. **Resolve the linked issue** (skip if step 2 found no issue):
   - **Complete fix** (`Closes #N`) — verify it auto-closed with
     `gh issue view <N> --json state,stateReason`. If still open, close explicitly:
     `gh issue close <N> --comment "Fixed in #<PR>."`
   - **Partial fix** (`Refs #N`) — leave it open and comment a pointer:
     `gh issue comment <N> --body "Partially addressed by #<PR>. Still pending: <summary>."`

6. **Report** what merged, the gate result, that the branch was deleted, and the final issue state
   (or "no linked issue").

## Tool compatibility

Write multiline commit messages and PR bodies to project-local `tmp/` files with
file-editing tools, then pass `-F` / `--body-file`. Use the current agent’s file-editing, shell, and session tools. Preserve unrelated work and local skill/configuration files during cleanup.
