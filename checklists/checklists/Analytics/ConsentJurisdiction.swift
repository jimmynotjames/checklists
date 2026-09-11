//
//  ConsentJurisdiction.swift
//  checklists
//

import Foundation

/// Classifies a device's region as requiring explicit opt-in consent for product analytics, or
/// as permitting auto opt-in.
///
/// Region codes are resolved from `Locale.current.region?.identifier` at the call site, so this
/// stays a pure function with no hidden dependency on the current locale. The table below
/// mirrors the canonical list in core-docs/analytics-spec.md §6.2; additions or removals should
/// update both the spec and this source together.
///
/// `nonisolated` on the type, not on each member: the target sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it every member here — including the
/// static lookup and the region set — would be reachable only from the main actor.
nonisolated enum ConsentJurisdiction: Equatable {
  /// Analytics require explicit, affirmative opt-in before any event may be sent.
  case required

  /// Analytics are default-on; the user may opt out at any time via the Settings toggle.
  case autoOptin

  // MARK: - Lookup

  /// Returns the jurisdiction kind for the given `Locale.Region` identifier string.
  ///
  /// - Parameter regionIdentifier: The ISO 3166-1 alpha-2 region code (e.g. `"DE"`, `"US"`), or
  ///   `nil` if `Locale.current.region` is unavailable. `nil` → `.required` (the conservative
  ///   default).
  static func kind(for regionIdentifier: String?) -> ConsentJurisdiction {
    guard let code = regionIdentifier else {
      return .required
    }
    return strictOptInRegions.contains(code) ? .required : .autoOptin
  }

  // MARK: - Private: canonical region list (analytics-spec.md §6.2)

  /// All regions that require explicit opt-in consent.
  ///
  /// Sources:
  /// - EU member states: GDPR + ePrivacy Directive
  /// - EEA (non-EU): IS, LI, NO — GDPR via the EEA agreement
  /// - GB, GG, JE, IM — UK GDPR + PECR
  /// - CH — revFADP
  /// - KR — PIPA
  /// - CN — PIPL
  /// - BR — LGPD
  /// - TR — KVKK
  /// - TH — PDPA
  /// - CA — Quebec Law 25, applied CA-wide as a pragmatic simplification
  ///
  /// To add or remove a region, update core-docs/analytics-spec.md §6.2 and this set together.
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
    // Canada (pragmatic CA-wide coverage for Quebec Law 25; see §6.2)
    "CA",
  ]
}
