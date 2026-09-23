//
//  MixpanelTokenSource.swift
//  checklists
//

/// The Mixpanel project token for the active build configuration, read from Info.plist.
///
/// `isConfigured` gates SDK initialization: when the active token is not a real one — a fresh
/// clone with no `config/Secrets.local.xcconfig`, or a half-filled one — the app falls back to
/// `ConsoleAnalyticsClient`. No Mixpanel traffic, no crash.
///
/// See core-docs/analytics-spec.md §Build hygiene.
enum MixpanelTokenSource {
  /// True when the token this build configuration will actually use is a real one. Checks only
  /// the active token, not both — so a filled-in prod token with a placeholder dev token doesn't
  /// silently pass as fine on a Debug build.
  static var isConfigured: Bool {
    isValidToken(activeToken)
  }

  /// Whether a string is shaped like a Mixpanel project token: 32 lowercase hex characters. Shape
  /// is the whole check, deliberately — the likeliest mistake is leaving
  /// `config/Secrets.local.xcconfig.template`'s placeholder in place, which is shaped like nothing
  /// real. Keep in step with `scripts/verify_release_secrets.sh`, which applies the same rule.
  static func isValidToken(_ token: String) -> Bool {
    token.count == 32 && token.allSatisfy(hexCharacters.contains)
  }

  static var activeToken: String {
    #if DEBUG
      AppConfig.mixpanelDevToken
    #else
      AppConfig.mixpanelProdToken
    #endif
  }

  private static let hexCharacters = Set("0123456789abcdef")
}
