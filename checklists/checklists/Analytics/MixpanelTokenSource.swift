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
/// `isConfigured` gates SDK initialization: when the active token is not a real one — a fresh
/// clone with no `config/Secrets.local.xcconfig`, or a half-filled one — the app falls back to
/// `ConsoleAnalyticsClient`. No Mixpanel traffic, no crash.
///
/// See core-docs/analytics-spec.md §10.
enum MixpanelTokenSource {
  /// True when the token this build configuration will actually use is a real one.
  ///
  /// Deliberately checks **only the active token**, not both. `budgets1` requires both to be
  /// filled in, which produces a bad failure: a maintainer who fills in the prod token but
  /// leaves the dev one at its placeholder gets a green ship guard and a Release build where
  /// this returns `false`, so every event silently goes to the console client. The ship guard
  /// (`scripts/verify_release_secrets.sh`) checks only the prod token for the same reason.
  static var isConfigured: Bool {
    isValidToken(activeToken)
  }

  /// Whether a string is shaped like a Mixpanel project token: 32 lowercase hex characters.
  ///
  /// Shape-checking rather than comparing against known placeholder strings. Blacklisting the
  /// sentinels let the likeliest mistake through — copying
  /// `config/Secrets.local.xcconfig.template` and forgetting to paste leaves
  /// `your_32_char_prod_token_here`, which is neither empty nor a sentinel, and would have
  /// initialized the SDK with a junk token that drops every event. This mirrors the identical
  /// check in `scripts/verify_release_secrets.sh`; keep the two in step.
  ///
  /// Pure, so tests never touch `Bundle.main` and do not depend on whether the machine running
  /// them has a secrets file.
  static func isValidToken(_ token: String) -> Bool {
    token.count == 32 && token.allSatisfy(hexCharacters.contains)
  }

  /// The token for the active build configuration.
  static var activeToken: String {
    #if DEBUG
      AppConfig.mixpanelDevToken
    #else
      AppConfig.mixpanelProdToken
    #endif
  }

  private static let hexCharacters = Set("0123456789abcdef")
}
