#!/usr/bin/env bash
# Bare compile step: catches build errors quickly without running the test suite.
#
# Deviation from budgets1's build.sh: that script boots the per-repo simulator and
# builds against its UDID. Here we use a generic simulator destination, so a plain
# `make build` never pays the 30–90 s boot. The per-repo simulator sandbox
# (scripts/_sim_sandbox.sh) is used only by the test scripts, which actually need
# a running device.
#
# The Xcode project lives one level down (checklists/checklists.xcodeproj); the
# repo root holds the tooling.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ARCHS=arm64 is REQUIRED, not an optimization. The vendored Flurry 11.2.0 static
# library (checklists/checklists/Flurry/libFlurry_11.2.0.a) is a 2020-era fat archive
# containing i386/armv7/x86_64/arm64 slices, and its x86_64 slice is malformed in a way
# the modern linker rejects outright:
#
#   ld: LINKEDIT overlap of start of LINKEDIT and symbol table strings in
#       'libFlurry_11.2.0.a(CrashReporter-x86_64-master.o)'
#
# A generic simulator destination builds every slice, so it hits the bad x86_64 object
# and fails. Xcode's own builds succeed because they build only the active arch. Pinning
# arm64 keeps the command-line build honest on Apple Silicon. Consequence: this project
# cannot currently be built for an x86_64 simulator (Intel Macs / Rosetta) at all —
# fixing that means upgrading or dropping the Flurry SDK. See AGENTS.md.
exec xcodebuild build \
    -project checklists/checklists.xcodeproj \
    -scheme checklists \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .build/DerivedData \
    -quiet \
    CODE_SIGNING_ALLOWED=NO \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO
