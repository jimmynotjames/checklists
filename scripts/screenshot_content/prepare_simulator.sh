#!/usr/bin/env bash
# Boot or reuse this checkout's capture simulator and print UDID<TAB>name.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
if [[ "$#" -ne 1 || -z "$1" ]]; then
    echo "usage: prepare_simulator.sh DEVICE_NAME" >&2
    exit 2
fi

if [[ -n "${SIMULATOR_UDID:-}" ]]; then
    echo "prepare_simulator: SIMULATOR_UDID is not accepted for marketing capture" >&2
    exit 2
fi

BASE_NAME="$1"
REPO_SLUG="$(python3 "${ROOT}/scripts/sim_common.py" slug "${ROOT}")"
DEVICE_NAME="${BASE_NAME} Screenshots [${REPO_SLUG}]"

python3 "${ROOT}/scripts/sim_retire_stale.py" --name "${DEVICE_NAME}"
UDID="$(python3 "${ROOT}/scripts/resolve_booted_sim_udid.py" --name "${DEVICE_NAME}" --state Booted)"
IS_BOOTED=0
[[ -n "${UDID}" ]] && IS_BOOTED=1
if [[ -z "${UDID}" ]]; then
    UDID="$(python3 "${ROOT}/scripts/resolve_booted_sim_udid.py" --name "${DEVICE_NAME}" --state any)"
fi
if [[ -z "${UDID}" ]]; then
    SPEC="$(python3 "${ROOT}/scripts/resolve_sim_spec.py" --name "${BASE_NAME}")"
    DEVICE_TYPE="$(printf '%s\n' "${SPEC}" | head -1)"
    RUNTIME="$(printf '%s\n' "${SPEC}" | tail -1)"
    UDID="$(xcrun simctl create "${DEVICE_NAME}" "${DEVICE_TYPE}" "${RUNTIME}")"
fi

if [[ "${IS_BOOTED}" -eq 0 ]]; then
    xcrun simctl boot "${UDID}"
fi
xcrun simctl bootstatus "${UDID}" -b >&2

printf '%s\t%s\n' "${UDID}" "${DEVICE_NAME}"
