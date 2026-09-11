//
//  ConsentJurisdictionTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// Pins the jurisdiction lookup in core-docs/analytics-spec.md §6.2, including the
/// conservative default for an unrecognized region — the easiest behaviour to regress.
///
/// See the note on `AnalyticsTextTests` for the `nonisolated` class / `@MainActor` method
/// pattern.
nonisolated final class ConsentJurisdictionTests: XCTestCase {
  private static let strictCodes = [
    // European Union
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT",
    "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE",
    // EEA non-EU
    "IS", "LI", "NO",
    // UK and Crown Dependencies
    "GB", "GG", "JE", "IM",
    // Everyone else on the list
    "CH", "KR", "CN", "BR", "TR", "TH", "CA",
  ]

  @MainActor func testEveryStrictCodeResolvesToRequired() {
    for code in Self.strictCodes {
      XCTAssertEqual(ConsentJurisdiction.kind(for: code), .required, "Regressed for \(code).")
    }
  }

  @MainActor func testRepresentativeAutoOptinRegions() {
    for code in ["US", "JP", "AU", "IN", "MX", "ZA"] {
      XCTAssertEqual(ConsentJurisdiction.kind(for: code), .autoOptin, "Regressed for \(code).")
    }
  }

  /// A device with no resolvable region (`Locale.current.region` is `nil`) must resolve to the
  /// conservative default, not to auto opt-in.
  @MainActor func testNilRegionResolvesToRequired() {
    XCTAssertEqual(ConsentJurisdiction.kind(for: nil), .required)
  }
}
