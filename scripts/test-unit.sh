#!/usr/bin/env bash
# Unit tests only (checklistsTests) — skips the UI test target.
#
# OPT-IN: not part of `make gate`. This is a 2020-era XCTest suite whose current
# pass/fail state has not been established; promoting it into the blocking gate is
# a separate decision. Run it explicitly with `make test-unit`.
#
# WARNING: DataModelTests deliberately tests against the PERSISTED Realm store, not
# an in-memory one, and calls `DBManager.realm.deleteAll()` in setUp. Running it
# WIPES THE APP'S DATABASE on whatever simulator it targets. The per-repo simulator
# sandbox contains that blast radius to this repo's own device — one more reason the
# sandbox is worth having here.
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
    -skip-testing:checklistsUITests \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO

# Signal to test-ui.sh that the sim has hosted an app lifecycle.
# Cleared automatically by make sim-clean (which wipes .build/sim/).
touch "${ROOT}/.build/sim/warmed"
