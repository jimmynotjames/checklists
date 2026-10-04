//
//  AdaptiveLayoutTests.swift
//  checklistsTests
//

@testable import checklists
import Testing
import UIKit

/// A 393×852 table resting at the top of its content.
private let restingTable = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)

/// Covers `ChecklistViewController.keyboardOverlap(keyboardFrame:tableBounds:)`: the keyboard
/// covers only what it overlaps, which is its full height only for a window filling the screen.
@Suite("How much of the checklist the keyboard covers")
struct ChecklistKeyboardOverlapTests {
  @Test("a docked keyboard under a full-screen table covers its full height")
  func dockedKeyboard() {
    let keyboard = CGRect(x: 0.0, y: 852.0 - 336.0, width: 393.0, height: 336.0)
    #expect(ChecklistViewController.keyboardOverlap(keyboardFrame: keyboard, tableBounds: restingTable) == 336.0)
  }

  /// A window ending above the screen's bottom edge — an iPad window, or a table laid out above the
  /// home indicator — is covered by less than the keyboard's height.
  @Test("a table ending above the screen bottom is covered by less than the keyboard's height")
  func tableEndingAboveScreenBottom() {
    let table = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 818.0)
    let keyboard = CGRect(x: 0.0, y: 852.0 - 336.0, width: 393.0, height: 336.0)
    #expect(ChecklistViewController.keyboardOverlap(keyboardFrame: keyboard, tableBounds: table) == 302.0)
  }

  @Test("a keyboard that misses the table covers nothing")
  func floatingKeyboardElsewhere() {
    let keyboard = CGRect(x: 500.0, y: 400.0, width: 320.0, height: 250.0)
    #expect(ChecklistViewController.keyboardOverlap(keyboardFrame: keyboard, tableBounds: restingTable) == 0.0)
  }

  @Test("a keyboard entirely below the table covers nothing")
  func keyboardBelowWindow() {
    let keyboard = CGRect(x: 0.0, y: 900.0, width: 393.0, height: 336.0)
    #expect(ChecklistViewController.keyboardOverlap(keyboardFrame: keyboard, tableBounds: restingTable) == 0.0)
  }

  /// With a hardware keyboard only the shortcuts bar shows.
  @Test("the hardware keyboard's shortcuts bar covers only its own height")
  func shortcutsBarOnly() {
    let bar = CGRect(x: 0.0, y: 852.0 - 55.0, width: 393.0, height: 55.0)
    #expect(ChecklistViewController.keyboardOverlap(keyboardFrame: bar, tableBounds: restingTable) == 55.0)
  }

  /// Bounds are content space: scrolled down, both frames move together and the overlap holds.
  @Test("a scrolled table is covered by the same amount")
  func scrolledTable() {
    let table = restingTable.offsetBy(dx: 0.0, dy: 1200.0)
    let keyboard = CGRect(x: 0.0, y: 1200.0 + 852.0 - 336.0, width: 393.0, height: 336.0)
    #expect(ChecklistViewController.keyboardOverlap(keyboardFrame: keyboard, tableBounds: table) == 336.0)
  }
}

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

  /// The guide is what the checklist screen's header, rows and Add button pin to.
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

  @Test("the main menu becomes a side panel only when the list beside it keeps the panel's width")
  func menuSidePanel() {
    #expect(!RootView.menuIsSidePanel(in: 393.0))
    #expect(!RootView.menuIsSidePanel(in: RootView.menuPanelWidth * 2.0 - 1.0))
    #expect(RootView.menuIsSidePanel(in: RootView.menuPanelWidth * 2.0))
  }
}
