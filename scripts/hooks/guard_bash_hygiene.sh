#!/usr/bin/env bash
# PreToolUse(Bash) guard for AGENTS.md §"Bash command hygiene" rules 1-6.
# Input: hook JSON on stdin -> .tool_input.command
# Output: on match, a JSON deny decision + exit 0 (deny is authoritative); else exit 0 silently.
set -euo pipefail

cmd="$(jq -r '.tool_input.command // ""')"

reason=""

if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_])(/private)?(/var)?/tmp/'; then
  reason='Blocked (hygiene rule 1): absolute /tmp/. Use the project-local tmp/ (gitignored, allowlisted). Redirect output to tmp/ rather than piping — a pipe discards the exit code (AGENTS.md §"Reading a test result").'
elif printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_/])sed +(-[a-zA-Z]*i|--in-place)'; then
  reason='Blocked (hygiene rule 2): do not use `sed -i` — use the Edit or Write tool instead.'
elif printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_/])sed +-[a-zA-Z]*n'; then
  reason='Blocked (hygiene rule 3): do not use `sed -n RANGE_p` to slice a file — use the Read tool with offset/limit instead.'
elif printf '%s' "$cmd" | grep -Eq 'git(\s+-C\s+\S+)?\s+push(\s+--[a-zA-Z-]+)*\s+\S{3,}\s+(main|gh-pages)\b'; then
  reason='Blocked (hygiene rule 4): never push directly to main or gh-pages (both have server-side protection). Branch as u/jimmyho/<tool>/<short-kebab-description> and open a PR. See AGENTS.md §"Conventions".'
elif printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_/])(pkill|killall)\b[^|&;]*\bSimulator\b'; then
  reason='Blocked (hygiene rule 5): never `pkill`/`killall Simulator` — it hits every simulator on the machine. Use `make sim-shutdown` / `make sim-clean` (this checkout'\''s devices only).'
elif printf '%s' "$cmd" | grep -Eq 'simctl\s+((shutdown|erase|delete)\s+all|delete\s+unavailable)\b'; then
  reason='Blocked (hygiene rule 5): machine-wide `simctl ... all`/`delete unavailable` is not allowed — scoped `simctl <verb> <udid>` stays allowed; otherwise use `make sim-shutdown` / `make sim-clean`.'
elif printf '%s' "$cmd" | grep -Eq '(^|;|\|&)[[:space:]]*nohup[[:space:]]'; then
  reason='Blocked (hygiene rule 6): do not use `nohup` — use the Bash tool'\''s run_in_background:true instead.'
fi

if [ -n "$reason" ]; then
  jq -nc --arg r "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
fi

exit 0
