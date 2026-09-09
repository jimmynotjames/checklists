//
//  MixpanelTokenSource.swift
//  checklists
//

/// The Mixpanel project token for the active build configuration, read from Info.plist.
///
/// Debug builds route to the "reChecklist App - Dev" project and Release builds to
/// "reChecklist App - Prod", so local instrumentation can be verified without polluting
/// production data. This is a deliberate departure from the Flurry integration, which compiled
/// analytics out of debug builds entirely and thereby made them impossible to check.
///
/// `isConfigured` gates SDK initialization: when the tokens are still the committed placeholder
/// sentinels — a fresh clone with no `config/Secrets.local.xcconfig` — the app falls back to
/// `ConsoleAnalyticsClient`. No Mixpanel traffic, no crash.
///
/// See core-docs/analytics-spec.md §10.
enum MixpanelTokenSource {
  /// True when both tokens are real values, meaning the local secrets file is present and filled.
  static var isConfigured: Bool {
    isConfigured(dev: AppConfig.mixpanelDevToken, prod: AppConfig.mixpanelProdToken)
  }

  /// Pure form of `isConfigured`, taking the tokens as arguments so tests never touch
  /// `Bundle.main` and do not depend on whether the machine running them has a secrets file.
  static func isConfigured(dev: String, prod: String) -> Bool {
    !dev.isEmpty
      && !prod.isEmpty
      && dev != AppConfig.Placeholder.mixpanelDevToken
      && prod != AppConfig.Placeholder.mixpanelProdToken
  }

  /// The token for the active build configuration.
  static var activeToken: String {
    #if DEBUG
      AppConfig.mixpanelDevToken
    #else
      AppConfig.mixpanelProdToken
    #endif
  }
}
