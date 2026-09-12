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

# ARCHS=arm64 is a BUILD-SPEED choice, not a correctness constraint.
#
# It used to be load-bearing: the vendored Flurry static library's x86_64 slice was
# malformed and the linker rejected it outright, so an unpinned build simply failed.
# Flurry has been removed and that constraint is gone — an unpinned build of this
# project now links clean for both slices (verified: `lipo -info` on the built binary
# reports "x86_64 arm64").
#
# The pin stays because the destination below is generic, so dropping it builds BOTH
# slices — which means compiling Realm's large C++ tree (realm-core, s2geometry) twice
# for no benefit. Every machine and CI runner that builds this project is Apple Silicon.
#
# Measured on an M4, clean DerivedData, warm SPM checkout: 56 s pinned vs 93 s unpinned.
# So the pin saves ~37 s (~40%) — real, but well short of halving, because the two slices
# share driver startup, SPM resolution, and asset-catalog work.
#
# If you ever need genuine x86_64 coverage: delete ARCHS=arm64 below but KEEP
# ONLY_ACTIVE_ARCH=NO — that is the flag that forces both slices to be built. Deleting both
# would fall back to the active arch only and give you the same single slice you have now.
# Signing is deliberately left at the project's default (automatic, ad-hoc against
# DEVELOPMENT_TEAM) rather than disabled.
#
# `CODE_SIGNING_ALLOWED=NO` skips ProcessProductPackaging, and with it the
# `checklists.app-Simulated.xcent` blob that carries the entitlements a *simulator*
# build gets — simulator entitlements live in that blob, not in the code signature,
# which is why `codesign -d --entitlements -` looks empty either way and hides the
# difference. Without it the binary has no `application-identifier`, so
# `CKContainer.default()` cannot resolve a container and CloudKit raises an
# Objective-C `CKException` ("containerIdentifier can not be nil"). That is not a
# Swift error, so the `do`/`catch` in ICloudStatusLoader.load(into:) cannot catch it
# and opening Settings kills the process (#140).
#
# The test scripts already build this way — they pass no CODE_SIGN* flags at all —
# so this only brings `make build` in line with `make test-unit` / `make test-ui`.
# The destination is a simulator, so no real identity or provisioning profile is
# needed: the result is still an ad-hoc signature with no Team ID.
exec xcodebuild build \
    -project checklists/checklists.xcodeproj \
    -scheme checklists \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath .build/DerivedData \
    -quiet \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO
