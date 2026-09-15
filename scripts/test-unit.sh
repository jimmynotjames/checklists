#!/usr/bin/env bash
# Unit tests only (checklistsTests) — skips the UI test target. OPT-IN, not in the gate.
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

RESULT_BUNDLE="${SIM_RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)-unit.xcresult"

xcodebuild test \
    -project checklists/checklists.xcodeproj \
    -scheme checklists \
    -destination "${DESTINATION}" \
    -destination-timeout 300 \
    -derivedDataPath "${SIM_DERIVED}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    -parallel-testing-enabled NO \
    -skip-testing:checklistsUITests

# Signal to test-ui.sh that the sim has hosted an app lifecycle.
# Cleared automatically by make sim-clean (which wipes .build/sim/).
touch "${ROOT}/.build/sim/warmed"
