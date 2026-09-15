//
//  AppConfig.swift
//  checklists
//

import Foundation

/// Typed access to configuration injected through Info.plist, which is built from the committed
/// `config/Secrets.xcconfig` plus the gitignored `config/Secrets.local.xcconfig`.
///
/// Reads happen at the call site against `Bundle.main` with no caching, and never trap. A fresh
/// clone has no local secrets file and must still build, launch, and run its tests; analytics
/// degrade to the console client instead — see `MixpanelTokenSource.isConfigured`.
///
/// Note the sentinel fallback below only fires if the Info.plist key is missing entirely. When
/// the key is present but its build setting is undefined, Xcode substitutes an **empty string**,
/// so that is the value callers actually see on a fresh clone. Both are rejected by
/// `MixpanelTokenSource.isValidToken`, which is what makes either safe.
///
/// An analytics token is never a source literal. It reaches the app only through this
/// indirection — see core-docs/analytics-spec.md §10, and `scripts/verify_release_secrets.sh`,
/// which refuses to ship a build whose token is still the committed placeholder.
enum AppConfig {
  /// Must stay in sync with the defaults in `config/Secrets.xcconfig` and the values
  /// `scripts/verify_release_secrets.sh` refuses to ship. `AppConfigSentinelTests` guards this.
  enum Placeholder {
    static let mixpanelDevToken = "PLACEHOLDER_MIXPANEL_DEV_TOKEN"
    static let mixpanelProdToken = "PLACEHOLDER_MIXPANEL_PROD_TOKEN"
  }

  static var mixpanelDevToken: String {
    Bundle.main.object(forInfoDictionaryKey: "MixpanelDevToken") as? String
      ?? Placeholder.mixpanelDevToken
  }

  static var mixpanelProdToken: String {
    Bundle.main.object(forInfoDictionaryKey: "MixpanelProdToken") as? String
      ?? Placeholder.mixpanelProdToken
  }
}
