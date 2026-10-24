//
//  PaperSizeTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// Covers the regional paper size an exported PDF is laid out on.
@Suite("Paper size")
struct PaperSizeTests {
  @Test("Letter regions get Letter", arguments: ["US", "CA", "MX", "PR", "PH", "us"])
  func letterRegions(region: String) {
    #expect(PaperSize.forRegion(region) == .letter)
  }

  @Test("other regions get A4", arguments: ["GB", "DE", "AU", "JP", "IN"])
  func a4Regions(region: String) {
    #expect(PaperSize.forRegion(region) == .a4)
  }

  @Test("an unknown region gets A4")
  func unknownRegionGetsA4() {
    #expect(PaperSize.forRegion(nil) == .a4)
  }
}
