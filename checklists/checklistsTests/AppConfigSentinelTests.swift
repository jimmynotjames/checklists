//
//  AppConfigSentinelTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// Guards the token plumbing added with the Mixpanel work: the placeholder sentinels in
/// `AppConfig.Placeholder`, and the token shape check in `MixpanelTokenSource`.
///
/// The sentinel strings are duplicated in three places that must agree —
/// `config/Secrets.xcconfig`, `AppConfig.Placeholder`, and `scripts/verify_release_secrets.sh`.
/// A test target cannot read the xcconfig or the shell script, so this covers the half it can:
/// that the Swift constants exist, are distinct, and can never be mistaken for a real token.
/// The other two are held together by review and by the spec (core-docs/analytics-spec.md §10).
///
/// See the note on `AnalyticsManagerTests` for why this is `nonisolated` at the type level with
/// `@MainActor` on the individual methods.
nonisolated final class AppConfigSentinelTests: XCTestCase {
  // MARK: - Sentinels

  @MainActor func testPlaceholdersAreNonEmptyAndDistinct() {
    XCTAssertFalse(AppConfig.Placeholder.mixpanelDevToken.isEmpty)
    XCTAssertFalse(AppConfig.Placeholder.mixpanelProdToken.isEmpty)
    XCTAssertNotEqual(
      AppConfig.Placeholder.mixpanelDevToken,
      AppConfig.Placeholder.mixpanelProdToken
    )
  }

  /// The sentinels must never pass the shape check, or a fresh clone would initialize the SDK
  /// with a placeholder and silently drop every event.
  @MainActor func testPlaceholdersAreNotValidTokens() {
    XCTAssertFalse(MixpanelTokenSource.isValidToken(AppConfig.Placeholder.mixpanelDevToken))
    XCTAssertFalse(MixpanelTokenSource.isValidToken(AppConfig.Placeholder.mixpanelProdToken))
  }

  // MARK: - Token shape

  @MainActor func testRealShapedTokenIsValid() {
    XCTAssertTrue(MixpanelTokenSource.isValidToken("0123456789abcdef0123456789abcdef"))
  }

  @MainActor func testEmptyTokenIsRejected() {
    XCTAssertFalse(MixpanelTokenSource.isValidToken(""))
  }

  /// An undefined build setting makes Xcode substitute an empty string into Info.plist, and a
  /// straight copy of `Secrets.local.xcconfig.template` leaves the "fill me in" text. Neither is
  /// empty *and* neither is a sentinel, so shape is the only check that catches both.
  @MainActor func testUnfilledTemplateValueIsRejected() {
    XCTAssertFalse(MixpanelTokenSource.isValidToken("your_32_char_prod_token_here"))
    XCTAssertFalse(MixpanelTokenSource.isValidToken("$(inherited)"))
  }

  @MainActor func testWrongLengthIsRejected() {
    XCTAssertFalse(MixpanelTokenSource.isValidToken(String(repeating: "a", count: 31)))
    XCTAssertFalse(MixpanelTokenSource.isValidToken(String(repeating: "a", count: 33)))
  }

  /// Mixpanel tokens are lowercase hex. Uppercase and non-hex letters are both rejected, so a
  /// mistyped or partially-redacted token cannot slip through on length alone.
  @MainActor func testNonLowercaseHexIsRejected() {
    XCTAssertFalse(MixpanelTokenSource.isValidToken("0123456789ABCDEF0123456789ABCDEF"))
    XCTAssertFalse(MixpanelTokenSource.isValidToken(String(repeating: "z", count: 32)))
  }
}
