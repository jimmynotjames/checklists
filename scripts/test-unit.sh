#!/usr/bin/env bash
# Unit tests only (checklistsTests) — skips the UI test target. Opt-in: AGENTS.md §"Build and test".
#
# Suites use in-memory ModelContainers (Helpers/TestModelContainer.swift) or per-test
# temp dirs (Helpers/TestScope.swift); nothing touches the simulator's real store.
#
# `-parallel-testing-enabled NO` is load-bearing for more than speed: it is also what
# keeps Swift Testing, which parallelizes within the process by default, running the
# suite serially.
#
# DESTINATION, SIM_DERIVED, and SIM_RESULTS_DIR are set by _destination.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source "${ROOT}/scripts/_destination.sh"

RESULT_BUNDLE="${SIM_RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)-$$-unit.xcresult"

# `|| RC=$?` so `set -e` doesn't skip the failure listing below.
RC=0
xcodebuild test \
    -project checklists/checklists.xcodeproj \
    -scheme checklists \
    -destination "${DESTINATION}" \
    -destination-timeout 300 \
    -derivedDataPath "${SIM_DERIVED}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    -parallel-testing-enabled NO \
    -skip-testing:checklistsUITests || RC=$?

python3 "${ROOT}/scripts/list_test_failures.py" "${RESULT_BUNDLE}" || true

# The warm sentinel: test-ui.sh's header.
if [[ "${RC}" -eq 0 ]]; then
    touch "${ROOT}/.build/sim/warmed"
fi

echo "result-bundle: ${RESULT_BUNDLE}"
exit "${RC}"
