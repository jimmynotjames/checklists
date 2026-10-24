//
//  PDFFileNameTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing

/// Covers the exported file's name, which the recipient sees on the attachment and in Files.
@Suite("PDF file name")
struct PDFFileNameTests {
  private let utc = TimeZone.gmt

  @Test("the name is the checklist name and the chosen date")
  func nameIsTitleAndDate() {
    let date = Date(timeIntervalSince1970: 1_792_756_800) // 2026-10-23 12:00 UTC

    #expect(PDFFileName.make(title: "Quality check", date: date, timeZone: utc) == "Quality check 2026-10-23.pdf")
  }

  /// Late evening in Los Angeles is already the next day in UTC; the file should carry the day
  /// the person picked.
  @Test("the date is the day in the chosen time zone")
  func dateUsesTheTimeZone() throws {
    let date = Date(timeIntervalSince1970: 1_792_803_600) // 2026-10-24 01:00 UTC, the evening before in LA
    let losAngeles = try #require(TimeZone(identifier: "America/Los_Angeles"))

    #expect(PDFFileName.make(title: "Job", date: date, timeZone: losAngeles) == "Job 2026-10-23.pdf")
  }

  @Test("path separators become dashes")
  func separatorsAreReplaced() {
    #expect(PDFFileName.sanitize("Job 3/4: kitchen") == "Job 3-4- kitchen")
  }

  @Test("line breaks become spaces")
  func lineBreaksBecomeSpaces() {
    #expect(PDFFileName.sanitize("Kitchen\nBathroom") == "Kitchen Bathroom")
  }

  @Test("a leading dot is dropped so the file is not hidden")
  func leadingDotIsDropped() {
    #expect(PDFFileName.sanitize("..profile") == "profile")
  }

  @Test("a name with nothing usable falls back to the untitled name")
  func emptyFallsBack() {
    #expect(PDFFileName.sanitize(" . ") == CommonStrings.defaultChecklistName)
  }

  @Test("a long name is cut without splitting a character")
  func longNameIsCutOnACharacter() {
    let cut = PDFFileName.sanitize(String(repeating: "é🔧", count: 200))

    #expect(cut.utf8.count <= 200)
    #expect(cut.unicodeScalars.allSatisfy { $0 == "é" || $0 == "🔧" })
  }
}
