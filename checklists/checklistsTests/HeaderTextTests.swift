//
//  HeaderTextTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// Covers the export sheet's Header rules: the insertion rule for Saved Headers and the
/// 30,000-character limit.
@Suite("Header text")
struct HeaderTextTests {
  @Test("inserting into an empty field adds no line break")
  func emptyFieldGetsNoLineBreak() {
    #expect(HeaderText.appendix(inserting: "Acme", into: "") == "Acme")
  }

  @Test("inserting after text starts the Saved Header on its own line")
  func textWithoutTrailingBreakGetsOne() {
    #expect(HeaderText.appendix(inserting: "Acme", into: "Job 42") == "\nAcme")
  }

  @Test("inserting after a trailing line break adds no second one")
  func trailingBreakIsNotDoubled() {
    #expect(HeaderText.appendix(inserting: "Acme", into: "Job 42\n") == "Acme")
  }

  @Test("an insertion that would pass the limit is cut to fit")
  func insertionIsCutAtTheLimit() {
    let current = String(repeating: "a", count: HeaderText.characterLimit - 3)

    #expect(HeaderText.appendix(inserting: "Acme", into: current) == "\nAc")
  }

  @Test("a full field takes nothing more")
  func fullFieldTakesNothing() {
    let current = String(repeating: "a", count: HeaderText.characterLimit)

    #expect(HeaderText.appendix(inserting: "Acme", into: current).isEmpty)
  }

  /// Swift's default count, as the spec says: an emoji is one character, not two UTF-16 units.
  @Test("the limit counts characters, so an emoji counts once")
  func limitCountsCharacters() {
    let capped = HeaderText.capped(String(repeating: "🔧", count: HeaderText.characterLimit + 5))

    #expect(capped.count == HeaderText.characterLimit)
  }

  @Test("normalizing trims surrounding whitespace and keeps inner line breaks")
  func normalizingKeepsInnerBreaks() {
    #expect(HeaderText.normalized("\n Acme\nLicence 12345 \n") == "Acme\nLicence 12345")
  }
}
