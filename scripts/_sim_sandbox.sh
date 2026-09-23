#!/usr/bin/env bash
# Sourceable helper: manages this checkout's simulator in the default CoreSimulator device set.
# Callers must set ROOT before sourcing (absolute path to repo root).
#
# Sets, for downstream scripts:
#   SIM_UDID        — UDID of this checkout's booted simulator
#   SIM_DERIVED     — path for xcodebuild -derivedDataPath
#   SIM_RESULTS_DIR — parent directory for -resultBundlePath
# SIMULATOR_NAME picks a different base device; SIMULATOR_UDID pins one and skips
# sandbox management. See AGENTS.md §"Simulator sandbox" / §"What NOT to do".

: "${ROOT:?ROOT must be set before sourcing _sim_sandbox.sh}"

SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"

# Scoped output paths — inside .build/ which is already gitignored
SIM_DERIVED="${ROOT}/.build/sim/DerivedData"
SIM_RESULTS_DIR="${ROOT}/.build/sim/results"
_UDID_FILE="${ROOT}/.build/sim/device.udid"

# Device name: base name + 8-char hash of the checkout path — AGENTS.md §"Simulator sandbox".
_REPO_SLUG="$(printf '%s' "${ROOT}" | shasum | cut -c1-8)"
_SIM_DEVICE_NAME="${SIMULATOR_NAME} [${_REPO_SLUG}]"

_pick_sim() {
    # $1: "Booted" or "any"
    python3 "${ROOT}/scripts/resolve_booted_sim_udid.py" \
        --name "${_SIM_DEVICE_NAME}" \
        --state "$1"
}

# The ConnectHardwareKeyboard preference is read at boot, so it is written before one.
# What it does and doesn't do: the XCUIElement+Keyboard.swift header.

_hw_keyboard_pref_ok() {
    # $1: UDID. True when the hardware keyboard is off, so the software one will show.
    python3 "${ROOT}/scripts/sim_keyboard_pref.py" --check "$1"
}

_write_keyboard_pref() {
    # $1: UDID. Safe to call whether or not the device is booted.
    python3 "${ROOT}/scripts/sim_keyboard_pref.py" --disable "$1"
}

# Every boot starts an unwarmed session; the sentinel's meaning is in test-ui.sh's header.
_invalidate_warm_sentinel() {
    rm -f "${ROOT}/.build/sim/warmed"
}

_fix_software_keyboard() {
    # $1: UDID of an already-booted device whose preference read back wrong.
    # The SIM-KEYBOARD-FLAKE tag: the XCUIElement+Keyboard.swift header.
    echo "SIM-KEYBOARD-FLAKE guard-fired: ConnectHardwareKeyboard wrong for $1 — see https://github.com/jimmynotjames/checklists/issues/231" >&2
    echo "sim-sandbox: software-keyboard preference wrong for $1 — cycling to fix" >&2
    _write_keyboard_pref "$1"
    xcrun simctl shutdown "$1"
    xcrun simctl boot "$1"
    open -a Simulator
    _wait_for_ready "$1"
    _invalidate_warm_sentinel
}

_ensure_sim_booted() {
    if [[ -n "${SIMULATOR_UDID:-}" ]]; then
        echo "sim-sandbox: SIMULATOR_UDID pinned — skipping sandbox management" >&2
        SIM_UDID="${SIMULATOR_UDID}"
        return
    fi

    mkdir -p "${ROOT}/.build/sim" "${SIM_DERIVED}" "${SIM_RESULTS_DIR}"

    # 0. Behind the newest installed iOS (e.g. after an Xcode upgrade) — delete it so
    #    step 3 recreates it on the new runtime instead of reusing the old one forever
    python3 "${ROOT}/scripts/sim_retire_stale.py" --name "${_SIM_DEVICE_NAME}"

    # 1. Already booted — reuse it (still call bootstatus to confirm UI services ready)
    local udid
    udid="$(_pick_sim Booted)"
    if [[ -n "${udid}" ]]; then
        echo "sim-sandbox: reusing booted ${_SIM_DEVICE_NAME} (${udid})" >&2
        _wait_for_ready "${udid}"
        _hw_keyboard_pref_ok "${udid}" || _fix_software_keyboard "${udid}"
        SIM_UDID="${udid}"
        printf '%s' "${SIM_UDID}" > "${_UDID_FILE}"
        return
    fi

    # 2. Exists but shutdown — set the keyboard pref before it boots, then boot and
    #    wait for full readiness
    udid="$(_pick_sim any)"
    if [[ -n "${udid}" ]]; then
        echo "sim-sandbox: booting existing ${_SIM_DEVICE_NAME} (${udid})" >&2
        _write_keyboard_pref "${udid}"
        _boot_and_wait "${udid}"
        open -a Simulator
        _invalidate_warm_sentinel
        SIM_UDID="${udid}"
        printf '%s' "${SIM_UDID}" > "${_UDID_FILE}"
        return
    fi

    # 3. No device yet — create one in the default set and boot it
    echo "sim-sandbox: resolving spec for ${SIMULATOR_NAME}..." >&2
    local spec device_type runtime
    spec="$(python3 "${ROOT}/scripts/resolve_sim_spec.py" --name "${SIMULATOR_NAME}")" || {
        echo "sim-sandbox: error: could not resolve device spec for '${SIMULATOR_NAME}'" >&2
        echo "sim-sandbox: install the latest iOS runtime in Xcode, or set SIMULATOR_UDID to an existing device" >&2
        exit 1
    }
    device_type="$(printf '%s\n' "${spec}" | head -1)"
    runtime="$(printf '%s\n' "${spec}" | tail -1)"

    echo "sim-sandbox: creating ${_SIM_DEVICE_NAME} (first-run, ~30–90s)" >&2
    udid="$(xcrun simctl create "${_SIM_DEVICE_NAME}" "${device_type}" "${runtime}")"
    echo "sim-sandbox: booting new ${_SIM_DEVICE_NAME} (${udid})" >&2
    _write_keyboard_pref "${udid}"
    _boot_and_wait "${udid}"
    open -a Simulator
    _invalidate_warm_sentinel
    SIM_UDID="${udid}"
    printf '%s' "${SIM_UDID}" > "${_UDID_FILE}"
}

# Boot the device if not booted, then block until it's fully ready (SpringBoard,
# accessibility services, etc.). `simctl boot` alone returns as soon as boot
# starts — UI tests will time out trying to talk to a half-booted simulator.
_boot_and_wait() {
    xcrun simctl bootstatus "$1" -b
}

# Wait for an already-booted device to finish coming up. Idempotent and fast
# when the device is already ready; blocks otherwise.
_wait_for_ready() {
    xcrun simctl bootstatus "$1"
}

_ensure_sim_booted
