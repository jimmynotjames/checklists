#!/usr/bin/env bash
# Sourceable helper: manages a per-repo simulator in the default CoreSimulator device set.
# Callers must set ROOT before sourcing (absolute path to repo root).
#
# Sets, for downstream scripts:
#   SIM_UDID        — UDID of a booted simulator for this repo
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

# Unique device name: base name + 8-char hash of the repo path.
# Ensures no two clones of this repo share a simulator, even on the same Mac.
_REPO_SLUG="$(printf '%s' "${ROOT}" | shasum | cut -c1-8)"
_SIM_DEVICE_NAME="${SIMULATOR_NAME} [${_REPO_SLUG}]"

_pick_sim() {
    # $1: "Booted" or "any"
    python3 "${ROOT}/scripts/resolve_booted_sim_udid.py" \
        --name "${_SIM_DEVICE_NAME}" \
        --state "$1"
}

# When the simulator's ConnectHardwareKeyboard preference is on, the software keyboard
# never appears. The preference is per-UDID but owned by Simulator.app, not the device,
# and is only read at boot — so it must be written before a boot, and Simulator.app must
# be open afterward for it to take effect at all.
#
# The UI tests no longer tap keyboard keys (see XCUIElement+Keyboard.swift), so this is
# belt-and-braces for ad-hoc runs and for anything that still needs the keyboard visible,
# not the load-bearing fix it used to be. Both helpers delegate to sim_keyboard_pref.py;
# its docstring explains why they go through `defaults` rather than the plist file.

_hw_keyboard_pref_ok() {
    # $1: UDID. True when the hardware keyboard is off, so the software one will show.
    python3 "${ROOT}/scripts/sim_keyboard_pref.py" --check "$1"
}

_write_keyboard_pref() {
    # $1: UDID. Safe to call whether or not the device is booted.
    python3 "${ROOT}/scripts/sim_keyboard_pref.py" --disable "$1"
}

# Any real boot transition (shutdown->boot, create->boot, or the self-heal cycle
# below) starts a session that hasn't hosted an app yet, which invalidates
# test-ui.sh's `warmed` sentinel (see its header comment: the XCUITest IPC socket
# isn't reliable until *this* booted session has run an app once). Without this,
# a rebooted-but-still-"warmed"-on-disk device produces confusing, wrong-cause test
# failures instead of test-ui.sh's own clear "run make test-unit first" error.
_invalidate_warm_sentinel() {
    rm -f "${ROOT}/.build/sim/warmed"
}

_fix_software_keyboard() {
    # $1: UDID of an already-booted device whose preference read back wrong.
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
