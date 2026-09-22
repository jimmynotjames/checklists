#!/usr/bin/env bash
# UI tests only (checklistsUITests). Does NOT re-run unit tests.
#
# OPT-IN: not part of `make gate`. See test-unit.sh for why.
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

RESULT_BUNDLE="${SIM_RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)-ui.xcresult"

# `|| RC=$?` rather than a bare call: `set -e` would otherwise exit here on a test failure and
# skip the tagging below. Do NOT rewrite this as `if ! xcodebuild …` — the `!` resets `$?` and the
# real exit code is lost, which is the same trap gate.sh documents.
RC=0
xcodebuild test \
    -project checklists/checklists.xcodeproj \
    -scheme checklists \
    -destination "${DESTINATION}" \
    -destination-timeout 300 \
    -derivedDataPath "${SIM_DERIVED}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    -parallel-testing-enabled NO \
    -only-testing:checklistsUITests/checklistsUITests \
    -only-testing:checklistsUITests/checklistUITest \
    -only-testing:checklistsUITests/checklistCreateUITest \
    -only-testing:checklistsUITests/ChecklistCopyCheckedItemsUITest \
    -only-testing:checklistsUITests/AnalyticsConsentUITest || RC=$?

# Tags keyboard-caused failures for issue #231 (is the keyboard machinery still needed?).
# Reports only; it never turns a pass into a failure or the reverse.
python3 "${ROOT}/scripts/check_keyboard_flake.py" "${RESULT_BUNDLE}" || true

exit "${RC}"
