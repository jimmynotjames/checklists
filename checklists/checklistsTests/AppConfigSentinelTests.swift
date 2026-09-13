//
//  AppConfigSentinelTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// Guards the token plumbing added with the Mixpanel work: the placeholder sentinels in
/// `AppConfig.Placeholder`, and the token shape check in `MixpanelTokenSource`.
///
/// The sentinel strings are duplicated in three places that must agree —
/// `config/Secrets.xcconfig`, `AppConfig.Placeholder`, and `scripts/verify_release_secrets.sh`.
/// A test target cannot read the xcconfig or the shell script, so this covers the half it can:
/// that the Swift constants exist, are distinct, and can never be mistaken for a real token.
/// The other two are held together by review and by the spec (core-docs/analytics-spec.md §10).
@Suite("AppConfig sentinel and token validity")
struct AppConfigSentinelTests {
  // MARK: - Sentinels

  @Test("placeholder tokens are non-empty and distinct")
  func placeholdersAreNonEmptyAndDistinct() {
    #expect(!AppConfig.Placeholder.mixpanelDevToken.isEmpty)
    #expect(!AppConfig.Placeholder.mixpanelProdToken.isEmpty)
    #expect(AppConfig.Placeholder.mixpanelDevToken != AppConfig.Placeholder.mixpanelProdToken)
  }

  /// The sentinels must never pass the shape check, or a fresh clone would initialize the SDK
  /// with a placeholder and silently drop every event.
  @Test("placeholder tokens never pass the validity check")
  func placeholdersAreNotValidTokens() {
    #expect(!MixpanelTokenSource.isValidToken(AppConfig.Placeholder.mixpanelDevToken))
    #expect(!MixpanelTokenSource.isValidToken(AppConfig.Placeholder.mixpanelProdToken))
  }

  // MARK: - Token shape

  @Test("a real-shaped token is valid")
  func realShapedTokenIsValid() {
    #expect(MixpanelTokenSource.isValidToken("0123456789abcdef0123456789abcdef"))
  }

  @Test("an empty token is rejected")
  func emptyTokenIsRejected() {
    #expect(!MixpanelTokenSource.isValidToken(""))
  }

  /// An undefined build setting makes Xcode substitute an empty string into Info.plist, and a
  /// straight copy of `Secrets.local.xcconfig.template` leaves the "fill me in" text. Neither is
  /// empty *and* neither is a sentinel, so shape is the only check that catches both.
  @Test("an unfilled template value is rejected")
  func unfilledTemplateValueIsRejected() {
    #expect(!MixpanelTokenSource.isValidToken("your_32_char_prod_token_here"))
    #expect(!MixpanelTokenSource.isValidToken("$(inherited)"))
  }

  @Test("a wrong-length token is rejected")
  func wrongLengthIsRejected() {
    #expect(!MixpanelTokenSource.isValidToken(String(repeating: "a", count: 31)))
    #expect(!MixpanelTokenSource.isValidToken(String(repeating: "a", count: 33)))
  }

  /// Mixpanel tokens are lowercase hex. Uppercase and non-hex letters are both rejected, so a
  /// mistyped or partially-redacted token cannot slip through on length alone.
  @Test("non-lowercase-hex tokens are rejected")
  func nonLowercaseHexIsRejected() {
    #expect(!MixpanelTokenSource.isValidToken("0123456789ABCDEF0123456789ABCDEF"))
    #expect(!MixpanelTokenSource.isValidToken(String(repeating: "z", count: 32)))
  }
}
