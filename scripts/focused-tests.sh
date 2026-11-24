#!/usr/bin/env bash
# One class or test, serially on this checkout's device, holding one simulator slot: the isolated
# rerun of AGENTS.md §"Reading a test result".
#
#   bash scripts/focused-tests.sh <target>/<Class>[/<test>] [iterations]   (default 1)
#
# XCTESTRUN=<path> runs a prebuilt build instead of building (prepare_test_args in _destination.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ $# -lt 1 || $# -gt 2 || -z "$1" ]]; then
    echo "usage: scripts/focused-tests.sh <target>/<Class>[/<test>] [iterations]" >&2
    exit 2
fi
ONLY="$1"
ITERATIONS="${2:-1}"

source "${ROOT}/scripts/_destination.sh"

RESULT_BUNDLE="${SIM_RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)-$$-focused.xcresult"

prepare_test_args
take_slots 1 focused-tests

if [[ "${ONLY}" == checklistsUITests/* ]]; then
    warm_up_if_needed
fi

# xcodebuild rejects `-test-iterations 1`, so the flag goes in only for a repeat run.
ITERATION_ARGS=()
if (( ITERATIONS > 1 )); then
    ITERATION_ARGS=(-test-iterations "${ITERATIONS}")
fi

# `|| RC=$?` so `set -e` doesn't skip the failure listing below.
RC=0
xcodebuild test-without-building "${TEST_ARGS[@]}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    -only-testing:"${ONLY}" \
    ${ITERATION_ARGS[@]+"${ITERATION_ARGS[@]}"} || RC=$?

python3 "${ROOT}/scripts/list_test_failures.py" "${RESULT_BUNDLE}" || true

echo "result-bundle: ${RESULT_BUNDLE}"
exit "${RC}"
