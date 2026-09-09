//
//  AnalyticsTextTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import XCTest

/// Covers `AnalyticsText.truncated(_:)`, which every user-supplied or error string passes
/// through before it is sent as a property value. No store involvement, so this needs none of the
/// container fixtures the other test classes use.
/// See the note on `DataModelTests` for why this is `nonisolated` at the type level: an implicitly
/// (or explicitly) MainActor-isolated `XCTestCase` subclass conflicts with the framework's own
/// nonisolated designated initializers, including one whose parameter type is unavailable in
/// Swift and so can't be overridden to fix. `AnalyticsText` (like every other unannotated type
/// in the app target) is implicitly MainActor-isolated too, so the individual test methods below
/// need `@MainActor`, same as the store-touching test classes.
nonisolated final class AnalyticsTextTests: XCTestCase {
  @MainActor func testUnderLimitStringIsUnchanged() {
    let input = "a short string"
    XCTAssertEqual(AnalyticsText.truncated(input), input)
  }

  @MainActor func testExactlyAtLimitIsUnchanged() {
    let input = String(repeating: "a", count: 127)
    let result = AnalyticsText.truncated(input)
    XCTAssertEqual(result, input)
    XCTAssertEqual(result.count, 127)
  }

  @MainActor func testOverLimitIsTruncatedTo127Characters() {
    let input = String(repeating: "a", count: 200)
    let result = AnalyticsText.truncated(input)
    XCTAssertEqual(result.count, 127)
    XCTAssertEqual(result, String(repeating: "a", count: 127))
  }

  /// `String.prefix` counts extended grapheme clusters ("Characters"), not UTF-8 bytes or Unicode
  /// scalars — the doc comment on `AnalyticsText.truncated` explicitly relies on this (127 was picked
  /// against a byte limit specifically in case it turned out to be counted in bytes). A
  /// multi-scalar emoji (a ZWJ family sequence — several Unicode scalars, one Character) placed
  /// right at the boundary proves the cut lands on a Character boundary, not mid-scalar: the
  /// truncated string is still valid text, not a corrupted partial sequence.
  @MainActor func testTruncationDoesNotSplitAMultiScalarEmojiAtTheBoundary() {
    let familyEmoji = "👨‍👩‍👧‍👦" // Single Character, multiple Unicode scalars joined by ZWJ.
    XCTAssertEqual(familyEmoji.count, 1, "Precondition: this emoji sequence must be exactly one Character.")

    let prefix126 = String(repeating: "a", count: 126)
    let input = prefix126 + familyEmoji + String(repeating: "b", count: 20)

    let result = AnalyticsText.truncated(input)

    XCTAssertEqual(result.count, 127)
    XCTAssertEqual(result, prefix126 + familyEmoji)
  }
}
