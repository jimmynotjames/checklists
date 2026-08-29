#!/usr/bin/env bash
# Single-command form of the gate (format-changed -> lint-changed -> build).
#
# Why this exists (inherited rationale from budgets1): the agent kept writing the
# gate as
#   (make format && make lint-fix && make build) > tmp/gate.log 2>&1; echo "EXIT=$?"
# Claude Code splits compound bash on (){};|&& and checks each segment against the
# allowlist; the subshell parens and trailing `; echo` produce segments like
# `(make format` and `make build) > tmp/gate.log 2>&1` that match no allow entry, so
# it prompts. Collapsing the whole thing into one script means the only command run
# is `bash scripts/gate.sh`, which a single `Bash(bash scripts/*)` entry already
# allows — no prompt, no subshell, no trailing echo.
#
# Deviation from budgets1: every step is scoped to the Swift files this branch
# actually changed (vs `main`), not the whole tree. budgets1 runs `swiftformat .`
# and `swiftlint --strict .` repo-wide, which it can afford because its tree is
# already clean. This is a 2020-era tree carrying ~96 pre-existing violations and
# 30/31 files needing reformat — repo-wide steps would rewrite the entire codebase
# on the first run and then block every commit. Scoping to changed files matches the
# staged-files-only pre-commit policy: code is brought up to standard as it is touched.
#
# `make format` / `make lint` (repo-wide) still exist as deliberate, manual escape
# hatches — they are just not what the gate runs.
#
# Also deviating: tests are NOT in the gate. See scripts/test-unit.sh.
#
# Logs everything to tmp/gate.log and stops at the first failing step. Exit code is
# that step's exit code (0 = all three passed). Run it in the background to get
# re-invoked on completion:  Bash(bash scripts/gate.sh, run_in_background=true)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG="tmp/gate.log"
mkdir -p tmp
: > "$LOG"

run_step() {
  local target="$1"
  local rc
  printf '=== make %s ===\n' "$target" | tee -a "$LOG"
  # Run first, capture $? immediately, THEN test. Do NOT write this as
  # `if ! make "$target"; then rc=$?; ...` — the `!` negation resets $? to 0, so the
  # failing step's real exit code is lost and gate.sh exits 0 on failure, silently
  # reporting a broken gate as green to the pre-push hook and to CI.
  make "$target" >>"$LOG" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '\nGATE FAILED at `make %s` (exit %d). Tail of %s:\n' "$target" "$rc" "$LOG"
    tail -40 "$LOG"
    exit "$rc"
  fi
}

run_step format-changed
run_step lint-changed
run_step build

printf '\nGATE PASSED (format-changed, lint-changed, build). Full log: %s\n' "$LOG"
