//
//  AppConfig.swift
//  checklists
//

import Foundation

/// Typed access to configuration injected through Info.plist, which is built from the committed
/// `config/Secrets.xcconfig` plus the gitignored `config/Secrets.local.xcconfig`.
///
/// Reads happen at the call site against `Bundle.main` with no caching, and fall back to the
/// placeholder sentinel rather than trapping. That fallback is the point: a fresh clone has no
/// local secrets file, and it must still build, launch, and run its tests. Analytics degrade to
/// the console client instead — see `MixpanelTokenSource.isConfigured`.
///
/// The Flurry key was a hardcoded literal in `AnalyticsManager.swift` for six years and is still
/// in this repo's history (issue #115). This indirection exists so that cannot recur.
enum AppConfig {
  // MARK: - Sentinels

  /// Must stay in sync with the defaults in `config/Secrets.xcconfig` and the values
  /// `scripts/verify_release_secrets.sh` refuses to ship. `AppConfigSentinelTests` guards this.
  enum Placeholder {
    static let mixpanelDevToken = "PLACEHOLDER_MIXPANEL_DEV_TOKEN"
    static let mixpanelProdToken = "PLACEHOLDER_MIXPANEL_PROD_TOKEN"
  }

  // MARK: - Bundle reads

  static var mixpanelDevToken: String {
    Bundle.main.object(forInfoDictionaryKey: "MixpanelDevToken") as? String
      ?? Placeholder.mixpanelDevToken
  }

  static var mixpanelProdToken: String {
    Bundle.main.object(forInfoDictionaryKey: "MixpanelProdToken") as? String
      ?? Placeholder.mixpanelProdToken
  }
}
