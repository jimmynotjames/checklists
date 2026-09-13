//
//  AnalyticsTextTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import Testing

/// Covers `AnalyticsText.truncated(_:)`, which every user-supplied or error string passes
/// through before it is sent as a property value. No store involvement, so this needs none of the
/// container fixtures the other test classes use.
@Suite("AnalyticsText truncation")
struct AnalyticsTextTests {
  @Test("a string under the limit is unchanged")
  func underLimitStringIsUnchanged() {
    let input = "a short string"
    #expect(AnalyticsText.truncated(input) == input)
  }

  @Test("a string exactly at the limit is unchanged")
  func exactlyAtLimitIsUnchanged() {
    let input = String(repeating: "a", count: 127)
    let result = AnalyticsText.truncated(input)
    #expect(result == input)
    #expect(result.count == 127)
  }

  @Test("a string over the limit is truncated to 127 characters")
  func overLimitIsTruncatedTo127Characters() {
    let input = String(repeating: "a", count: 200)
    let result = AnalyticsText.truncated(input)
    #expect(result.count == 127)
    #expect(result == String(repeating: "a", count: 127))
  }

  /// `String.prefix` counts extended grapheme clusters ("Characters"), not UTF-8 bytes or Unicode
  /// scalars — the doc comment on `AnalyticsText.truncated` explicitly relies on this (127 was picked
  /// against a byte limit specifically in case it turned out to be counted in bytes). A
  /// multi-scalar emoji (a ZWJ family sequence — several Unicode scalars, one Character) placed
  /// right at the boundary proves the cut lands on a Character boundary, not mid-scalar: the
  /// truncated string is still valid text, not a corrupted partial sequence.
  @Test("truncation does not split a multi-scalar emoji at the boundary")
  func truncationDoesNotSplitAMultiScalarEmojiAtTheBoundary() {
    let familyEmoji = "👨‍👩‍👧‍👦" // Single Character, multiple Unicode scalars joined by ZWJ.
    #expect(familyEmoji.count == 1, "Precondition: this emoji sequence must be exactly one Character.")

    let prefix126 = String(repeating: "a", count: 126)
    let input = prefix126 + familyEmoji + String(repeating: "b", count: 20)

    let result = AnalyticsText.truncated(input)

    #expect(result.count == 127)
    #expect(result == prefix126 + familyEmoji)
  }
}
