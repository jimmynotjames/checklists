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

xcodebuild test \
    -project checklists/checklists.xcodeproj \
    -scheme checklists \
    -destination "${DESTINATION}" \
    -destination-timeout 300 \
    -derivedDataPath "${SIM_DERIVED}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    -parallel-testing-enabled NO \
    -only-testing:checklistsUITests \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO
