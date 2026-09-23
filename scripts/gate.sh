#!/usr/bin/env bash
# Single-command form of the gate; the step list is AGENTS.md §"Build and test".
#
# One script so the whole gate is a single allowlisted command (a subshell or trailing
# ; echo splits into segments that prompt).
#
# Format and lint are scoped to changed Swift files; tests are not in the gate —
# AGENTS.md §"Lint policy".
#
# Logs everything to tmp/gate.log and stops at the first failing step. Exit code is
# that step's exit code (0 = every step passed). Run it in the background to get
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
# Before the build: it is the cheapest step and catches an unkeyed or untranslated
# string without waiting on a compile.
run_step i18n-check
# Also cheap, and also better answered before a compile: a keyboard-key tap in a UI test
# is a failure that only shows up on a differently-configured simulator.
run_step uitest-check
# Pure text checks: dangling doc pointers, names that no longer exist in the code, and history
# narrated on added lines.
run_step doc-check
run_step build

printf '\nGATE PASSED (format-changed, lint-changed, i18n-check, uitest-check, doc-check, build). Full log: %s\n' "$LOG"
