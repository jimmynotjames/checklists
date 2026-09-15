#!/usr/bin/env bash
# Sourceable helper: resolves the xcodebuild -destination string for test runs.
# Callers must set ROOT before sourcing. Sources _sim_sandbox.sh, which sets
# DESTINATION, SIM_DERIVED, and SIM_RESULTS_DIR.
# Override SIMULATOR_NAME (device) or SIMULATOR_UDID (pin a device, skip sandboxing).

: "${ROOT:?ROOT must be set to the repo root before sourcing _destination.sh}"

source "${ROOT}/scripts/_sim_sandbox.sh"

# Always pin by UDID so xcodebuild never resolves to an unintended device.
DESTINATION="platform=iOS Simulator,id=${SIM_UDID}"
