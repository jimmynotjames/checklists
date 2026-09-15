#!/usr/bin/env bash
# Bare compile step: no tests, generic destination, never boots a simulator.
# ARCHS=arm64 is a build-speed choice, not correctness (Realm's C++ tree compiles once);
# to build x86_64 drop ARCHS=arm64 but keep ONLY_ACTIVE_ARCH=NO.
# Signing is deliberately the project default: CODE_SIGNING_ALLOWED=NO skips the
# simulated .xcent, CKContainer.default() then raises an uncatchable ObjC CKException (#140).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

exec xcodebuild build \
    -project checklists/checklists.xcodeproj \
    -scheme checklists \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .build/DerivedData \
    -quiet \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO
