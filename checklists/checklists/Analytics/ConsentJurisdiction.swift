//
//  ConsentJurisdiction.swift
//  checklists
//

import Foundation

/// Classifies a device's region as requiring explicit opt-in consent for product analytics, or
/// as permitting auto opt-in.
///
/// Region codes are resolved from `Locale.current.region?.identifier` at the call site, so this
/// stays a pure function with no hidden dependency on the current locale.
///
/// nonisolated on the type: see AnalyticsEvent.
nonisolated enum ConsentJurisdiction: Equatable {
  /// Analytics require explicit, affirmative opt-in before any event may be sent.
  case required

  /// Analytics are default-on; the user may opt out at any time via the Settings toggle.
  case autoOptin

  /// `nil` → `.required` (the conservative default); a code not in `strictOptInRegions` →
  /// `.autoOptin`.
  static func kind(for regionIdentifier: String?) -> ConsentJurisdiction {
    guard let code = regionIdentifier else {
      return .required
    }
    return strictOptInRegions.contains(code) ? .required : .autoOptin
  }

  // MARK: - Private: canonical region list

  /// All regions that require explicit opt-in consent. Canonical list; analytics-spec.md
  /// §Consent points here.
  private static let strictOptInRegions: Set<String> = [
    // European Union (27 member states)
    "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE",
    "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV",
    "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
    "SI", "ES", "SE",
    // EEA non-EU
    "IS", "LI", "NO",
    // United Kingdom and Crown Dependencies
    "GB", "GG", "JE", "IM",
    // Switzerland
    "CH",
    // South Korea
    "KR",
    // China (mainland)
    "CN",
    // Brazil
    "BR",
    // Turkey
    "TR",
    // Thailand
    "TH",
    // Canada (CA-wide, to cover Quebec Law 25)
    "CA",
  ]
}
