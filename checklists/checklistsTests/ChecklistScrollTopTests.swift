//
//  ChecklistScrollTopTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import Testing
import UIKit

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

/// The distance a reader has actually scrolled, which is what both behaviours below key off:
/// a table inset under a navigation bar rests at `-topInset`, not at `0.0`.
private func makeScrollView(scrolledBy distance: CGFloat, topInset: CGFloat) -> UIScrollView {
  makeScrollView(offsetY: distance - topInset, topInset: topInset)
}

/// Covers `ChecklistViewController.isAtTop(_:)`: the top of an inset table is
/// `-adjustedContentInset.top`, not a literal content offset of `0.0` (#145).
@Suite("Recognising the top of the checklist list")
struct ChecklistScrollTopTests {
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

/// Covers the hand-off from the header's name field to the navigation bar's title, which fires on
/// distance scrolled rather than on a raw content offset (#145).
///
/// The threshold is 52.0, just clear of the name field at 22-54 in the header. Driving
/// `scrollViewDidScroll` directly keeps the view unloaded — loading it reaches
/// `PersistenceController.shared`, which is not installed in this target — and the title branches
/// touch only `navigationItem`.
@Suite("Swapping the checklist name into the navigation bar")
struct ChecklistTitleThresholdTests {
  private static let barInset: CGFloat = 44.0

  private func makeViewController() throws -> ChecklistViewController {
    let container = try TestModelContainer.make()
    let context = ModelContext(container)
    let checklist = Checklist()
    checklist.name = "Groceries"
    context.insert(checklist)
    try context.save()

    let viewController = ChecklistViewController()
    viewController.checklist = checklist
    return viewController
  }

  @Test("the title stays out of the bar while the list rests at the top")
  func titleAbsentAtRest() throws {
    let viewController = try makeViewController()

    viewController.scrollViewDidScroll(makeScrollView(scrolledBy: 0.0, topInset: Self.barInset))

    #expect(viewController.navigationItem.title == nil)
  }

  /// The case a raw content offset gets wrong: 60 points of scrolling reads as an offset of 16
  /// under a 44-point bar, which is below the threshold even though the name has gone.
  @Test("the title appears once the name field has scrolled past")
  func titleAppearsPastThreshold() throws {
    let viewController = try makeViewController()

    viewController.scrollViewDidScroll(makeScrollView(scrolledBy: 60.0, topInset: Self.barInset))

    #expect(viewController.navigationItem.title == "Groceries")
  }

  @Test("the title stays out while the name field is still on screen")
  func titleAbsentBeforeThreshold() throws {
    let viewController = try makeViewController()

    viewController.scrollViewDidScroll(makeScrollView(scrolledBy: 20.0, topInset: Self.barInset))

    #expect(viewController.navigationItem.title == nil)
  }

  /// Scrolling back up hands the name to the header again.
  @Test("the title leaves the bar on the way back to the top")
  func titleClearsOnReturnToTop() throws {
    let viewController = try makeViewController()
    viewController.scrollViewDidScroll(makeScrollView(scrolledBy: 60.0, topInset: Self.barInset))

    viewController.scrollViewDidScroll(makeScrollView(scrolledBy: 0.0, topInset: Self.barInset))

    #expect(viewController.navigationItem.title == nil)
  }

  /// An uninset table has no bar to hide behind, so the threshold is the offset itself.
  @Test("an uninset table swaps the title at the raw offset")
  func uninsetTableSwapsAtRawOffset() throws {
    let viewController = try makeViewController()

    viewController.scrollViewDidScroll(makeScrollView(offsetY: 60.0, topInset: 0.0))

    #expect(viewController.navigationItem.title == "Groceries")
  }
}
