#!/usr/bin/env bash
# One class or test, serially on this checkout's device, holding one simulator slot: the isolated
# rerun of AGENTS.md §"Reading a test result".
#
#   bash scripts/test-only.sh <target>/<Class>[/<test>] [iterations]   (default 1)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 || $# -gt 2 || -z "$1" ]]; then
    echo "usage: scripts/test-only.sh <target>/<Class>[/<test>] [iterations]" >&2
    exit 2
fi
ONLY="$1"
ITERATIONS="${2:-1}"

source "${ROOT}/scripts/_destination.sh"

RESULT_BUNDLE="${SIM_RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)-$$-only.xcresult"
COMMON_ARGS=(
    -project checklists/checklists.xcodeproj
    -scheme checklists
    -destination "${DESTINATION}"
    -destination-timeout 300
    -derivedDataPath "${SIM_DERIVED}"
)

xcodebuild build-for-testing "${COMMON_ARGS[@]}"
simulator_slots_hold 1 test-only "${ROOT}" "${SIM_UDID}" "[${SIM_SLUG}]"

if [[ "${ONLY}" == checklistsUITests/* ]]; then
    warm_up_if_needed
fi

# `|| RC=$?` so `set -e` doesn't skip the failure listing below.
RC=0
xcodebuild test-without-building "${COMMON_ARGS[@]}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    -only-testing:"${ONLY}" \
    -test-iterations "${ITERATIONS}" || RC=$?

python3 "${ROOT}/scripts/list_test_failures.py" "${RESULT_BUNDLE}" || true

echo "result-bundle: ${RESULT_BUNDLE}"
exit "${RC}"
