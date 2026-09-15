//
//  SettingsManagerTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import Testing

/// Covers `SettingsManager.versionBuildString` and the `AppTheme` enum.
///
/// `setCurrentAppTheme`/`currentAppTheme` are deliberately NOT covered here: it's an in-memory
/// TODO stub (the doc comment says "notifications" are still unimplemented) backing a themes UI
/// that's intentionally shelved for now.
@Suite("SettingsManager and AppTheme")
struct SettingsManagerTests {
  @Test("versionBuildString appends a DEBUG suffix in a debug build")
  func versionBuildStringFormat() {
    let value = SettingsManager.versionBuildString

    // Test targets always build Debug (see AGENTS.md on ONLY_ACTIVE_ARCH/test configuration), so
    // the " - DEBUG" suffix `versionBuildString` appends under `#if DEBUG` is always present here.
    #expect(value.hasSuffix(" - DEBUG"), "Expected a \" - DEBUG\" suffix in a Debug test build, got \"\(value)\"")
    let base = String(value.dropLast(" - DEBUG".count))

    // Format is "<version> (<build>)" — no "v" prefix (current behavior, not the "vX.Y (Z)" one
    // might guess from similar apps).
    #expect(base.contains(" ("), "Expected a \" (\" separator before the build number, got \"\(base)\"")
    #expect(base.hasSuffix(")"), "Expected the build number to be parenthesized, got \"\(base)\"")
    #expect(!base.hasPrefix("v"), "Current versionBuildString has no \"v\" prefix.")
  }

  /// Cheap regression pin on `AppTheme`'s case count and raw values — the type's own doc comment
  /// warns "order and continuity of numbers matter; might be used in switch statements elsewhere."
  @Test("AppTheme has exactly three cases with contiguous raw values")
  func appThemeCasesAndRawValues() {
    #expect(AppTheme.defaultBougie.rawValue == 0)
    #expect(AppTheme.extraBougie.rawValue == 1)
    #expect(AppTheme.unicorns.rawValue == 2)

    let knownCases = (0 ... 10).compactMap { AppTheme(rawValue: $0) }
    #expect(knownCases.count == 3, "Expected exactly 3 AppTheme cases with contiguous raw values 0...2.")
  }
}
