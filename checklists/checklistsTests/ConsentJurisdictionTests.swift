//
//  ConsentJurisdictionTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// Pins the jurisdiction lookup in core-docs/analytics-spec.md §Strict-opt-in jurisdictions, including the
/// conservative default for an unrecognized region — the easiest behaviour to regress.
@Suite("Consent jurisdiction lookup")
struct ConsentJurisdictionTests {
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

  @Test("every strict code resolves to required")
  func everyStrictCodeResolvesToRequired() {
    for code in Self.strictCodes {
      #expect(ConsentJurisdiction.kind(for: code) == .required, "Regressed for \(code).")
    }
  }

  @Test("representative regions resolve to auto opt-in")
  func representativeAutoOptinRegions() {
    for code in ["US", "JP", "AU", "IN", "MX", "ZA"] {
      #expect(ConsentJurisdiction.kind(for: code) == .autoOptin, "Regressed for \(code).")
    }
  }

  /// A device with no resolvable region (`Locale.current.region` is `nil`) must resolve to the
  /// conservative default, not to auto opt-in.
  @Test("a nil region resolves to required, the conservative default")
  func nilRegionResolvesToRequired() {
    #expect(ConsentJurisdiction.kind(for: nil) == .required)
  }
}
