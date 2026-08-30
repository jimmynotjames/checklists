#!/usr/bin/env bash
# Print the Swift files this branch has touched, one per line (empty output if none).
#
# Used by `make format-changed` / `make lint-changed`, which are what `make gate` runs.
# The whole point is to keep the gate scoped to code you actually changed: this is a
# 2020-era tree with ~96 pre-existing SwiftLint violations and 30/31 files needing
# reformat, so repo-wide steps would rewrite everything and then block every commit.
#
# The union of:
#   1. committed changes on this branch vs the merge-base with main  (main...HEAD)
#   2. uncommitted changes in the working tree                       (HEAD)
#   3. new, not-yet-added files                                      (ls-files --others)
# so the gate covers work whether or not it has been committed — or even added — yet.
# (3) matters: a brand-new .swift file is invisible to `git diff HEAD` until it is
# staged, so without it the gate would silently skip exactly the code most likely to
# need linting.
#
# --diff-filter=d excludes deletions (a deleted file cannot be linted). Files that no
# longer exist on disk are filtered out again at the end for safety (e.g. renames).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BASE_BRANCH="${BASE_BRANCH:-main}"

{
  # Only compare against the base branch if it actually exists (a fresh clone or a
  # detached checkout may not have it); otherwise fall back to working-tree changes.
  if git rev-parse --verify --quiet "${BASE_BRANCH}" >/dev/null; then
    git diff --name-only --diff-filter=d "${BASE_BRANCH}...HEAD" -- '*.swift'
  fi
  git diff --name-only --diff-filter=d HEAD -- '*.swift'
  git ls-files --others --exclude-standard -- '*.swift'
} | sort -u | while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  printf '%s\n' "$f"
done
