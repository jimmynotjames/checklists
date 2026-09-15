#!/usr/bin/env bash
# Single-command form of the gate (format-changed -> lint-changed -> build).
#
# One script so the whole gate is a single allowlisted command (a subshell or trailing
# ; echo splits into segments that prompt).
#
# Scoped to changed Swift files; tests are not in the gate — AGENTS.md §"Lint policy".
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
