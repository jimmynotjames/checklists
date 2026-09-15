//
//  AnalyticsTextTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import Testing

/// Covers `AnalyticsText.truncated(_:)`, which every user-supplied string passes
/// through before it is sent as a property value.
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

  /// `String.prefix` counts extended grapheme clusters, not UTF-8 bytes or Unicode scalars (127 was
  /// picked in case it turned out to be byte-counted); a ZWJ family emoji at the boundary proves the cut lands on a Character boundary, not mid-scalar.
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
