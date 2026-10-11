#!/usr/bin/env bash
# UI tests only (checklistsUITests). Does NOT re-run unit tests. Opt-in: AGENTS.md §"Build and test".
#
# IMPORTANT: the simulator must have hosted at least one prior app lifecycle before
# the XCUITest IPC socket is reliable. test-unit.sh writes the `warmed` sentinel
# after a successful run; a serial run refuses to start without it. `make sim-clean`
# wipes .build/sim/ so the sentinel auto-clears on simulator reset. A parallel run skips the
# check: xcodebuild shuts this device down to clone it, so the next boot clears the sentinel,
# and the clones boot fresh either way.
#
# UI_WORKERS (default 2) is how many simulators to ask the slot pool for; the run takes what is
# free and splits the test classes across that many clones (AGENTS.md §"Simulator slots").
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source "${ROOT}/scripts/_destination.sh"

RESULT_BUNDLE="${SIM_RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)-$$-ui.xcresult"
COMMON_ARGS=(
    -project checklists/checklists.xcodeproj
    -scheme checklists
    -destination "${DESTINATION}"
    -destination-timeout 300
    -derivedDataPath "${SIM_DERIVED}"
)

xcodebuild build-for-testing "${COMMON_ARGS[@]}"
slots_parallel_args "${UI_WORKERS:-2}" test-ui

WARM_SENTINEL="${ROOT}/.build/sim/warmed"
if [[ "${SIMULATOR_SLOTS_GRANTED}" -le 1 && ! -f "${WARM_SENTINEL}" ]]; then
    echo "error: simulator not warmed up, and this run got only one slot so it runs serially on it." >&2
    echo "  Run 'make test-unit' before 'make test-ui'." >&2
    echo "  If you just ran make sim-clean / make initialize-sims, run 'make test-unit' first." >&2
    exit 1
fi

# `|| RC=$?` so `set -e` doesn't skip the tagging below; never `if ! xcodebuild` (see gate.sh).
RC=0
# `-collect-test-diagnostics never`: nothing here reads the simulator diagnostics, and collecting
# them once hung for its full 600 s timeout after a passing run.
# The skipped screenshot captures have their own drivers (fastlane,
# translation-accessibility-size-check).
xcodebuild test-without-building "${COMMON_ARGS[@]}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    "${SLOTS_PARALLEL_ARGS[@]}" \
    -collect-test-diagnostics never \
    -only-testing:checklistsUITests \
    -skip-testing:checklistsUITests/AppStoreScreenshots \
    -skip-testing:checklistsUITests/LocalizationScreenshotCapture || RC=$?

python3 "${ROOT}/scripts/list_test_failures.py" "${RESULT_BUNDLE}" || true

echo "result-bundle: ${RESULT_BUNDLE}"
exit "${RC}"
