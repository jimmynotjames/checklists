//
//  CircularPercentStatusIconTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import Testing
import UIKit

/// Covers `CircularPercentStatusIcon`'s accessibility contract (`accessibilityValue`;
/// `accessibilityLabel` is deliberately nil) and its per-`IconType` dimensions, not the private arc/bezier drawing math.
@Suite("CircularPercentStatusIcon accessibility and dimensions")
struct CircularPercentStatusIconTests {
  @Test("0% progress reports as 0 percent complete")
  func accessibilityValueAtZeroPercent() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    icon.percentageComplete = 0.0
    #expect(icon.accessibilityValue == "Checklist 0% complete")
  }

  @Test("a fractional percent complete rounds to the nearest whole percent")
  func accessibilityValueAtFractionalPercentRoundsToNearestWhole() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    icon.percentageComplete = 2.0 / 11.0 // 18.18...%
    #expect(icon.accessibilityValue == "Checklist 18% complete")
  }

  @Test("100% progress reports as 100 percent complete")
  func accessibilityValueAtFullPercent() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    icon.percentageComplete = 1.0
    #expect(icon.accessibilityValue == "Checklist 100% complete")
  }

  /// The `didSet` that derives `accessibilityValue` does not run for `percentageComplete`'s own
  /// default, so an icon nobody assigns to has to pick the value up from `commonInit` instead —
  /// otherwise VoiceOver reaches a focusable element with nothing to announce.
  @Test("picks up its accessibility value from commonInit before any assignment")
  func accessibilityValueIsPopulatedBeforeAnyAssignment() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    #expect(icon.accessibilityValue == "Checklist 0% complete")
  }

  @Test("the icon is its own accessibility element")
  func iconIsItsOwnAccessibilityElement() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    #expect(icon.isAccessibilityElement)
  }

  /// `ChecklistRowView` announces the row's progress by calling this, so the icon's own value and
  /// the SwiftUI row's declared value cannot drift apart.
  @Test("accessibilityValueText matches what the icon itself announces")
  func accessibilityValueTextMatchesTheValueTheIconAnnounces() {
    for percentageComplete in [0.0, 2.0 / 11.0, 0.5, 1.0] as [CGFloat] {
      let icon = CircularPercentStatusIcon(iconType: .row)
      icon.percentageComplete = percentageComplete
      #expect(
        icon.accessibilityValue ==
          CircularPercentStatusIcon.accessibilityValueText(forPercentageComplete: percentageComplete)
      )
    }
  }

  @Test("accessibilityValueText rounds to the nearest whole percent")
  func accessibilityValueTextRoundsToNearestWhole() {
    #expect(
      CircularPercentStatusIcon.accessibilityValueText(forPercentageComplete: 2.0 / 11.0) ==
        "Checklist 18% complete"
    )
    #expect(
      CircularPercentStatusIcon.accessibilityValueText(forPercentageComplete: 1.0) ==
        "Checklist 100% complete"
    )
  }

  @Test("accessibility label is nil")
  func accessibilityLabelIsNil() {
    // The percent complete is only meaningful as the accessibility *value*; the label is
    // deliberately nil so VoiceOver doesn't announce a redundant/awkward "value, value".
    let icon = CircularPercentStatusIcon(iconType: .header)
    #expect(icon.accessibilityLabel == nil)
  }

  // MARK: - Per-IconType dimensions

  /// `radius`/`innerRadius`/`outerRingLineWidth` are private; the dimension table's observable
  /// contract is the view's own laid-out size (2 * radius, per `updateConstraints()`), which
  /// `systemLayoutSizeFitting` can compute from the view's self-contained height/width constraints
  /// without needing a superview or window.
  @Test("a row icon lays out at 20x20 for radius 10")
  func tableViewCellIconTypeDimensions() {
    let icon = CircularPercentStatusIcon(iconType: .row)
    icon.updateConstraintsIfNeeded()
    let size = icon.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    #expect(size == CGSize(width: 20.0, height: 20.0)) // radius 10.0
  }

  @Test("a header icon lays out at 24x24 for radius 12")
  func headerIconTypeDimensions() {
    let icon = CircularPercentStatusIcon(iconType: .header)
    icon.updateConstraintsIfNeeded()
    let size = icon.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    #expect(size == CGSize(width: 24.0, height: 24.0)) // radius 12.0
  }

  // No test mutates `iconType` on a live instance: without a window, `systemLayoutSizeFitting`
  // doesn't reliably re-solve after `setNeedsUpdateConstraints()` — a harness limitation, not a
  // product bug.
}
