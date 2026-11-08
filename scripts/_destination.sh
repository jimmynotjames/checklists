#!/usr/bin/env bash
# Sourceable helper: resolves the xcodebuild -destination string for test runs.
# Callers must set ROOT before sourcing. Sources _sim_sandbox.sh, which sets
# SIM_UDID, SIM_DERIVED, and SIM_RESULTS_DIR; this file turns SIM_UDID into DESTINATION.
# Override SIMULATOR_NAME (device) or SIMULATOR_UDID (pin a device, skip sandboxing).
#
# Also defines take_slots and slots_parallel_args for the scripts that run tests (AGENTS.md
# §"Simulator slots").

: "${ROOT:?ROOT must be set to the repo root before sourcing _destination.sh}"

source "${ROOT}/scripts/_sim_sandbox.sh"

# Always pin by UDID so xcodebuild never resolves to an unintended device.
DESTINATION="platform=iOS Simulator,id=${SIM_UDID}"

SIMULATOR_SLOTS_HOME="${ROOT}/scripts/simulator-slots"
source "${SIMULATOR_SLOTS_HOME}/simulator_slots.sh"

# The pool is opt-in per machine: on, only where the master copy exists. Elsewhere (someone else's
# clone) nothing takes a slot and the test scripts leave parallelism to the scheme.
if [[ -d "${SIMULATOR_SLOTS_MASTER:-${HOME}/dev/simulator-slots}" ]]; then
    SIMULATOR_SLOTS_ENABLED=1
else
    SIMULATOR_SLOTS_ENABLED=0
fi

# Takes up to $1 slots for a run labelled $2 and sets SIMULATOR_SLOTS_GRANTED; with the pool off,
# takes none and grants $1 capped at SIMULATOR_WORKERS_WITHOUT_POOL (default 1). That cap is the
# per-checkout knob for a machine that runs only this repo's tests, such as a CI runner. Call it
# after building and before testing, so builds never hold a slot.
take_slots() {
    if [[ "${SIMULATOR_SLOTS_ENABLED}" -eq 0 ]]; then
        local cap="${SIMULATOR_WORKERS_WITHOUT_POOL:-1}"
        SIMULATOR_SLOTS_GRANTED=$(( $1 < cap ? $1 : cap ))
        return 0
    fi
    simulator_slots_hold "$1" "$2" "${ROOT}" "${SIM_UDID}" "[${SIM_SLUG}]"
}

# take_slots, then sets SLOTS_PARALLEL_ARGS to the xcodebuild flags for the granted count: serial
# on this checkout's device for 1, that many clones for more. With the pool off and 1 granted, no
# flags: the scheme's own setting (serial) applies.
slots_parallel_args() {
    take_slots "$1" "$2" || return $?
    if [[ "${SIMULATOR_SLOTS_ENABLED}" -eq 0 && "${SIMULATOR_SLOTS_GRANTED}" -le 1 ]]; then
        SLOTS_PARALLEL_ARGS=()
    elif [[ "${SIMULATOR_SLOTS_GRANTED}" -le 1 ]]; then
        SLOTS_PARALLEL_ARGS=(-parallel-testing-enabled NO)
    else
        SLOTS_PARALLEL_ARGS=(-parallel-testing-enabled YES
            -parallel-testing-worker-count "${SIMULATOR_SLOTS_GRANTED}"
            -maximum-parallel-testing-workers "${SIMULATOR_SLOTS_GRANTED}")
        # Clones an interrupted run left behind; safe under the checkout lock _sim_sandbox.sh holds.
        python3 "${ROOT}/scripts/sim_clean.py" --clones-only >&2
    fi
}

# A UI test run on this checkout's own device needs the `warmed` sentinel (test-ui.sh's header).
# Without it, runs the already-built unit tests here first, which write it. Call after taking a
# slot; uses the caller's COMMON_ARGS.
warm_up_if_needed() {
    [[ -f "${ROOT}/.build/sim/warmed" ]] && return 0
    echo "sim: device not warmed up; running the unit tests on it first" >&2
    xcodebuild test-without-building "${COMMON_ARGS[@]}" \
        -resultBundlePath "${SIM_RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)-$$-warmup.xcresult" \
        -parallel-testing-enabled NO \
        -collect-test-diagnostics never \
        -skip-testing:checklistsUITests >&2 || {
        echo "error: the warm-up unit tests failed; run 'make test-unit' to see why." >&2
        return 1
    }
    touch "${ROOT}/.build/sim/warmed"
}
