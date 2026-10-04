#!/usr/bin/env bash
# UI tests only (checklistsUITests). Does NOT re-run unit tests. Opt-in: AGENTS.md §"Build and test".
#
# IMPORTANT: the simulator must have hosted at least one prior app lifecycle before
# the XCUITest IPC socket is reliable. test-unit.sh writes the `warmed` sentinel
# after a successful run; this script refuses to start without it. `make sim-clean`
# wipes .build/sim/ so the sentinel auto-clears on simulator reset.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source "${ROOT}/scripts/_destination.sh"

WARM_SENTINEL="${ROOT}/.build/sim/warmed"
if [[ ! -f "${WARM_SENTINEL}" ]]; then
    echo "error: simulator not warmed up." >&2
    echo "  Run 'make test-unit' before 'make test-ui'." >&2
    echo "  If you just ran make sim-clean / make initialize-sims, run 'make test-unit' first." >&2
    exit 1
fi

RESULT_BUNDLE="${SIM_RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)-$$-ui.xcresult"

# `|| RC=$?` so `set -e` doesn't skip the tagging below; never `if ! xcodebuild` (see gate.sh).
RC=0
# `-collect-test-diagnostics never`: nothing here reads the simulator diagnostics, and collecting
# them once hung for its full 600 s timeout after a passing run.
xcodebuild test \
    -project checklists/checklists.xcodeproj \
    -scheme checklists \
    -destination "${DESTINATION}" \
    -destination-timeout 300 \
    -derivedDataPath "${SIM_DERIVED}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    -only-testing:checklistsUITests/checklistsUITests \
    -only-testing:checklistsUITests/checklistUITest \
    -only-testing:checklistsUITests/checklistCreateUITest \
    -only-testing:checklistsUITests/ChecklistCopyCheckedItemsUITest \
    -only-testing:checklistsUITests/ChecklistReorderItemsUITest \
    -only-testing:checklistsUITests/AnalyticsConsentUITest || RC=$?

# Report-only keyboard-failure tag: the XCUIElement+Keyboard.swift header.
python3 "${ROOT}/scripts/check_keyboard_flake.py" "${RESULT_BUNDLE}" || true
python3 "${ROOT}/scripts/list_test_failures.py" "${RESULT_BUNDLE}" || true

echo "result-bundle: ${RESULT_BUNDLE}"
exit "${RC}"
