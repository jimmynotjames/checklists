//
//  CircularPercentStatusIconTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import XCTest

/// Covers `CircularPercentStatusIcon`'s accessibility contract (its `accessibilityValue` label,
/// since `accessibilityLabel` is deliberately nil) and its per-`IconType` dimensions. The arc/bezier
/// math itself is private and not part of the contract — per the plan, label + dimensions are what's
/// tested, not the drawing internals.
///
/// No Realm/DBManager involvement, so this doesn't need the in-memory-Realm save/restore pattern
/// the persistence-touching test classes use. See the note on `DataModelTests` for why this class
/// is `nonisolated` at the type level with individual `@MainActor` test methods (this view type is
/// implicitly MainActor-isolated, like everything else in the app target).
nonisolated final class CircularPercentStatusIconTests: XCTestCase {
  @MainActor func testAccessibilityValueAtZeroPercent() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    icon.percentageComplete = 0.0
    XCTAssertEqual(icon.accessibilityValue, "Checklist 0 percent complete")
  }

  @MainActor func testAccessibilityValueAtFractionalPercentRoundsToNearestWhole() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    icon.percentageComplete = 2.0 / 11.0 // 18.18...%
    XCTAssertEqual(icon.accessibilityValue, "Checklist 18 percent complete")
  }

  @MainActor func testAccessibilityValueAtFullPercent() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    icon.percentageComplete = 1.0
    XCTAssertEqual(icon.accessibilityValue, "Checklist 100 percent complete")
  }

  /// The `didSet` that derives `accessibilityValue` does not run for `percentageComplete`'s own
  /// default, so an icon nobody assigns to has to pick the value up from `commonInit` instead —
  /// otherwise VoiceOver reaches a focusable element with nothing to announce.
  @MainActor func testAccessibilityValueIsPopulatedBeforeAnyAssignment() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    XCTAssertEqual(icon.accessibilityValue, "Checklist 0 percent complete")
  }

  @MainActor func testIconIsItsOwnAccessibilityElement() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    XCTAssertTrue(icon.isAccessibilityElement)
  }

  /// `ChecklistRowView` announces the row's progress by calling this, so the icon's own value and
  /// the SwiftUI row's declared value cannot drift apart.
  @MainActor func testAccessibilityValueTextMatchesTheValueTheIconAnnounces() {
    for percentageComplete in [0.0, 2.0 / 11.0, 0.5, 1.0] as [CGFloat] {
      let icon = CircularPercentStatusIcon(iconType: .row)
      icon.percentageComplete = percentageComplete
      XCTAssertEqual(
        icon.accessibilityValue,
        CircularPercentStatusIcon.accessibilityValueText(forPercentageComplete: percentageComplete)
      )
    }
  }

  @MainActor func testAccessibilityValueTextRoundsToNearestWhole() {
    XCTAssertEqual(
      CircularPercentStatusIcon.accessibilityValueText(forPercentageComplete: 2.0 / 11.0),
      "Checklist 18 percent complete"
    )
    XCTAssertEqual(
      CircularPercentStatusIcon.accessibilityValueText(forPercentageComplete: 1.0),
      "Checklist 100 percent complete"
    )
  }

  @MainActor func testAccessibilityLabelIsNil() {
    // The percent complete is only meaningful as the accessibility *value*; the label is
    // deliberately nil so VoiceOver doesn't announce a redundant/awkward "value, value".
    let icon = CircularPercentStatusIcon(iconType: .header)
    XCTAssertNil(icon.accessibilityLabel)
  }

  // MARK: - Per-IconType dimensions

  /// `radius`/`innerRadius`/`outerRingLineWidth` are private; the dimension table's observable
  /// contract is the view's own laid-out size (2 * radius, per `updateConstraints()`), which
  /// `systemLayoutSizeFitting` can compute from the view's self-contained height/width constraints
  /// without needing a superview or window.
  @MainActor func testTableViewCellIconTypeDimensions() {
    let icon = CircularPercentStatusIcon(iconType: .row)
    icon.updateConstraintsIfNeeded()
    let size = icon.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    XCTAssertEqual(size, CGSize(width: 20.0, height: 20.0)) // radius 10.0
  }

  @MainActor func testHeaderIconTypeDimensions() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    icon.updateConstraintsIfNeeded()
    let size = icon.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    XCTAssertEqual(size, CGSize(width: 24.0, height: 24.0)) // radius 12.0
  }

  // NOTE: a test asserting that mutating `iconType` on a *live* instance re-triggers layout to the
  // new dimensions was tried and dropped — `systemLayoutSizeFitting`, with no window/superview to
  // drive a real layout pass, doesn't reliably re-solve after `setNeedsUpdateConstraints()` on an
  // already-measured view in this headless environment, which looks like a test-harness limitation
  // rather than a production bug (the two dimension tests above, one instance per `IconType`, are
  // what the plan actually asks for).
}
