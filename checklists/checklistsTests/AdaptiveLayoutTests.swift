//
//  AdaptiveLayoutTests.swift
//  checklistsTests
//

@testable import checklists
import Testing
import UIKit

@Suite("Centering content on a wide window")
struct ReadableColumnTests {
  @Test("an iPhone-width window gets no margin")
  func narrowWindow() {
    #expect(readableColumnMargin(for: 393.0) == 0.0)
  }

  @Test("a window exactly the column's width gets no margin")
  func exactWidth() {
    #expect(readableColumnMargin(for: readableColumnMaxWidth) == 0.0)
  }

  @Test("an unfolded iPhone Duo centers the column")
  func wideWindow() {
    #expect(readableColumnMargin(for: 1000.0) == (1000.0 - readableColumnMaxWidth) / 2.0)
  }

  @Test("the UIKit guide fills a narrow view and caps and centers in a wide one")
  func layoutGuide() {
    for (width, expectedWidth) in [(393.0, 393.0), (1200.0, readableColumnMaxWidth)] {
      let view = UIView(frame: CGRect(x: 0.0, y: 0.0, width: width, height: 100.0))
      let guide = view.addReadableColumnGuide()
      view.layoutIfNeeded()
      #expect(guide.layoutFrame.width == expectedWidth)
      // Auto Layout's engine resolves to within a hair of the exact centre, not onto it.
      #expect(abs(guide.layoutFrame.midX - width / 2.0) < 0.01)
    }
  }
}
