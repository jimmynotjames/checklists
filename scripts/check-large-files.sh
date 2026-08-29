#!/usr/bin/env bash
# Reject staged files larger than 1 MiB (accidental binaries, huge fixtures).
#
# Ported from budgets1. Its version skips .xcstrings catalogs (which grow with
# translations); this repo has no localization catalogs, but it DOES carry a vendored
# 32 MiB Flurry static archive that is already committed. The hook only ever sees
# STAGED files, so that archive is dormant — but it would hard-block the moment the
# file is re-staged (an SDK bump, say). It is skipped explicitly rather than left as a
# trap for whoever eventually upgrades Flurry.
set -euo pipefail

MAX_BYTES=$((1024 * 1024))
failed=0

if [[ $# -eq 0 ]]; then
  exit 0
fi

file_size() {
  local path="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f%z "$path"
  else
    stat -c%s "$path"
  fi
}

for path in "$@"; do
  [[ -f "$path" ]] || continue
  # Vendored Flurry SDK binary — already in history at ~32 MiB, intentionally exempt.
  [[ "$path" == *Flurry/libFlurry_*.a ]] && continue
  size="$(file_size "$path")"
  if (( size > MAX_BYTES )); then
    printf 'error: file exceeds 1 MiB (%s bytes): %s\n' "$size" "$path" >&2
    failed=1
  fi
done

exit "$failed"
