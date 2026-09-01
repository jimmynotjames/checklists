//
//  SettingsManagerTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import XCTest

/// Covers `SettingsManager.versionBuildString` and the `AppTheme` enum. No Realm/DBManager
/// involvement, so this doesn't need the in-memory-Realm save/restore pattern the other Phase 4
/// test classes use.
///
/// `setCurrentAppTheme`/`currentAppTheme` are deliberately NOT covered here: it's an in-memory
/// TODO stub (the doc comment says "notifications" are still unimplemented) backing a themes UI
/// that's intentionally shelved for now.
/// See the note on `DataModelTests` for why this is `nonisolated` at the type level.
/// `SettingsManager` (a class, unlike the plain `AppTheme` enum) is implicitly MainActor-isolated,
/// so `testVersionBuildStringFormat` needs `@MainActor`; `testAppThemeCasesAndRawValues` doesn't
/// touch anything isolated and stays plain.
nonisolated final class SettingsManagerTests: XCTestCase {
  @MainActor func testVersionBuildStringFormat() {
    let value = SettingsManager.versionBuildString

    // Test targets always build Debug (see AGENTS.md on ONLY_ACTIVE_ARCH/test configuration), so
    // the " - DEBUG" suffix `versionBuildString` appends under `#if DEBUG` is always present here.
    XCTAssertTrue(value.hasSuffix(" - DEBUG"), "Expected a \" - DEBUG\" suffix in a Debug test build, got \"\(value)\"")
    let base = String(value.dropLast(" - DEBUG".count))

    // Format is "<version> (<build>)" — no "v" prefix (current behavior, not the "vX.Y (Z)" one
    // might guess from similar apps).
    XCTAssertTrue(base.contains(" ("), "Expected a \" (\" separator before the build number, got \"\(base)\"")
    XCTAssertTrue(base.hasSuffix(")"), "Expected the build number to be parenthesized, got \"\(base)\"")
    XCTAssertFalse(base.hasPrefix("v"), "Current versionBuildString has no \"v\" prefix.")
  }

  /// Cheap regression pin on `AppTheme`'s case count and raw values — the type's own doc comment
  /// warns "order and continuity of numbers matter; might be used in switch statements elsewhere."
  func testAppThemeCasesAndRawValues() {
    XCTAssertEqual(AppTheme.defaultBougie.rawValue, 0)
    XCTAssertEqual(AppTheme.extraBougie.rawValue, 1)
    XCTAssertEqual(AppTheme.unicorns.rawValue, 2)

    let knownCases = (0 ... 10).compactMap { AppTheme(rawValue: $0) }
    XCTAssertEqual(knownCases.count, 3, "Expected exactly 3 AppTheme cases with contiguous raw values 0...2.")
  }
}
