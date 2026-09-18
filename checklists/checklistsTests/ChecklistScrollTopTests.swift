//
//  ChecklistScrollTopTests.swift
//  checklistsTests
//

@testable import checklists
import Testing
import UIKit

/// Covers `ChecklistViewController.isAtTop(_:)`: the top of an inset table is
/// `-adjustedContentInset.top`, not a literal content offset of `0.0` (#145).
@Suite("Recognising the top of the checklist list")
struct ChecklistScrollTopTests {
  /// `adjustedContentInset` is read-only, so the navigation bar's inset has to be stubbed.
  private final class InsetScrollView: UIScrollView {
    var stubbedAdjustedContentInset: UIEdgeInsets = .zero

    override var adjustedContentInset: UIEdgeInsets {
      stubbedAdjustedContentInset
    }
  }

  private func makeScrollView(offsetY: CGFloat, topInset: CGFloat) -> UIScrollView {
    let scrollView = InsetScrollView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0))
    scrollView.contentSize = CGSize(width: 390.0, height: 4000.0)
    scrollView.stubbedAdjustedContentInset = UIEdgeInsets(top: topInset, left: 0.0, bottom: 0.0, right: 0.0)
    scrollView.contentOffset = CGPoint(x: 0.0, y: offsetY)
    return scrollView
  }

  /// The table's resting position when laid out under a navigation bar.
  @Test("a table resting under the navigation bar is at the top")
  func restingUnderNavigationBarIsAtTop() {
    #expect(ChecklistViewController.isAtTop(makeScrollView(offsetY: -96.0, topInset: 96.0)))
  }

  /// A content offset of zero sits a bar's height below the real top once the table carries a
  /// navigation-bar inset.
  @Test("a literal zero offset under a navigation bar is not the top")
  func literalZeroUnderNavigationBarIsNotAtTop() {
    #expect(ChecklistViewController.isAtTop(makeScrollView(offsetY: 0.0, topInset: 96.0)) == false)
  }

  @Test("an uninset table is at the top at a zero offset")
  func uninsetTableIsAtTopAtZero() {
    #expect(ChecklistViewController.isAtTop(makeScrollView(offsetY: 0.0, topInset: 0.0)))
  }

  /// The reset-completion handoff reloads on this check, so a near miss must not strand it.
  @Test("a scroll that lands a hair short of the top still counts")
  func nearMissCountsAsAtTop() {
    #expect(ChecklistViewController.isAtTop(makeScrollView(offsetY: -95.8, topInset: 96.0)))
  }

  @Test("a scrolled table is not at the top")
  func scrolledTableIsNotAtTop() {
    #expect(ChecklistViewController.isAtTop(makeScrollView(offsetY: 240.0, topInset: 96.0)) == false)
  }
}
