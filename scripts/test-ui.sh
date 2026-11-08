#!/usr/bin/env bash
# UI tests only (checklistsUITests). Does NOT re-run unit tests. Opt-in: AGENTS.md §"Build and test".
#
# IMPORTANT: the simulator must have hosted at least one prior app lifecycle before
# the XCUITest IPC socket is reliable. test-unit.sh writes the `warmed` sentinel
# after a successful run, and every boot clears it (`make sim-clean` too). A serial run without
# it warms the device up first (`warm_up_if_needed`). A parallel run doesn't: its clones boot
# fresh, and xcodebuild shuts this device down to clone it.
#
# UI_WORKERS (default 2) is how many simulators to ask the slot pool for; the run takes what is
# free and splits the test classes across that many clones (AGENTS.md §"Simulator slots"). Where
# the pool is off, the run is serial unless SIMULATOR_WORKERS_WITHOUT_POOL allows more
# (`take_slots` in _destination.sh).
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

if [[ "${SIMULATOR_SLOTS_GRANTED}" -le 1 ]]; then
    warm_up_if_needed
fi

# `|| RC=$?` so `set -e` doesn't skip the tagging below; never `if ! xcodebuild` (see gate.sh).
RC=0
# `-collect-test-diagnostics never`: nothing here reads the simulator diagnostics, and collecting
# them once hung for its full 600 s timeout after a passing run.
# The skipped screenshot captures have their own drivers (fastlane,
# translation-accessibility-size-check).
xcodebuild test-without-building "${COMMON_ARGS[@]}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    ${SLOTS_PARALLEL_ARGS[@]+"${SLOTS_PARALLEL_ARGS[@]}"} \
    -collect-test-diagnostics never \
    -only-testing:checklistsUITests \
    -skip-testing:checklistsUITests/AppStoreScreenshots \
    -skip-testing:checklistsUITests/LocalizationScreenshotCapture || RC=$?

python3 "${ROOT}/scripts/list_test_failures.py" "${RESULT_BUNDLE}" || true

echo "result-bundle: ${RESULT_BUNDLE}"
exit "${RC}"
