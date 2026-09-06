#!/usr/bin/env bash
# Unit tests only (checklistsTests) — skips the UI test target.
#
# OPT-IN: not part of `make gate`. This suite compiles and passes (89 tests across
# DataModelTests, ModelBehaviorTests, SampleDataTests, SortKeyReorderTests,
# LegacyRealmImporterTests, ProductionContainerFactoryTests, PersistentStoreURLTests,
# RemoteChangeObserverTests, TwoDeviceUnionTests, SampleDataDedupeTests,
# AnalyticsManagerTests, SettingsManagerTests,
# CircularPercentStatusIconTests, CLTextViewTests, and ItemContentViewTests);
# promoting it into the blocking gate is a separate decision. Run it explicitly with
# `make test-unit`.
#
# Every class runs against a disposable in-memory ModelContainer (see
# checklistsTests/Helpers/TestModelContainer.swift), except LegacyRealmImporterTests,
# which writes real Realm fixture files to the test process's own temporary directory
# and removes them in tearDown. Nothing here touches the simulator's real on-disk
# store — a deliberate break from the Realm-era DataModelTests, which asserted against
# the persisted store and wiped it in setUp.
#
# DESTINATION, SIM_DERIVED, and SIM_RESULTS_DIR are set by _destination.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

source "${ROOT}/scripts/_destination.sh"

RESULT_BUNDLE="${SIM_RESULTS_DIR}/$(date +%Y%m%d_%H%M%S)-unit.xcresult"

xcodebuild test \
    -project checklists/checklists.xcodeproj \
    -scheme checklists \
    -destination "${DESTINATION}" \
    -destination-timeout 300 \
    -derivedDataPath "${SIM_DERIVED}" \
    -resultBundlePath "${RESULT_BUNDLE}" \
    -parallel-testing-enabled NO \
    -skip-testing:checklistsUITests

# Signal to test-ui.sh that the sim has hosted an app lifecycle.
# Cleared automatically by make sim-clean (which wipes .build/sim/).
touch "${ROOT}/.build/sim/warmed"
