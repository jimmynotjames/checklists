#!/usr/bin/env bash
# Sourceable helper: resolves the xcodebuild -destination string for TEST runs.
# Callers must set ROOT before sourcing (absolute path to repo root).
#
# After sourcing, DESTINATION is set for use with xcodebuild -destination.
# SIM_DERIVED and SIM_RESULTS_DIR are also available (set by _sim_sandbox.sh).
#
# Override SIMULATOR_NAME to select a different device (default: iPhone 17).
# Override SIMULATOR_UDID to pin a specific device and skip sandbox management.
#
# NOTE: `simple-recurring-budgets` also sources a _sim_concurrency.sh here to fan the UI suite out
# across simulator clones (its SRB_SIM_MAX knob). This repo's UI suite is not part
# of the gate and is small, so that layer is deliberately not ported — tests run
# serially on the single per-repo device.

: "${ROOT:?ROOT must be set to the repo root before sourcing _destination.sh}"

source "${ROOT}/scripts/_sim_sandbox.sh"

# Always pin by UDID so xcodebuild never resolves to an unintended device.
DESTINATION="platform=iOS Simulator,id=${SIM_UDID}"
