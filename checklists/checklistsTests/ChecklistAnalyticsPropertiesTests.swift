//
//  ChecklistAnalyticsPropertiesTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import XCTest

/// Covers the two pure mappings that feed events: `Checklist.analyticsViewedProperties` and
/// `orientationAnalyticsValue`.
///
/// `analyticsViewedProperties` is also where this app's PII boundary is drawn in code
/// (analytics-spec.md §4), so the negative assertions below — that no note text and no item name
/// appears anywhere in the payload — are the point of the class, not padding.
///
/// See the note on `AnalyticsTextTests` for the `nonisolated` class / `@MainActor` method pattern.
nonisolated final class ChecklistAnalyticsPropertiesTests: XCTestCase {
  /// `ModelContext(container)` rather than `container.mainContext`: the context initializer
  /// retains its container, whereas chaining off `.mainContext` lets the container deallocate at
  /// the end of the statement and the context crashes on first use. Same helper the other model
  /// test classes use.
  @MainActor private func makeContext() throws -> ModelContext {
    try ModelContext(TestModelContainer.make())
  }

  @MainActor
  private func makeChecklist(
    in context: ModelContext,
    name: String,
    notes: String? = nil,
    items: [(name: String, notes: String?)] = []
  ) -> Checklist {
    let checklist = Checklist(name: name, notes: notes, sortKey: 1.0)
    context.insert(checklist)
    for (index, spec) in items.enumerated() {
      let item = Item(name: spec.name, notes: spec.notes, sortKey: Double(index + 1))
      // Insert first, then wire the inverse — the order the other model tests use. Setting the
      // relationship on a model the context does not yet know about traps at runtime.
      context.insert(item)
      item.checklist = checklist
    }
    return checklist
  }

  @MainActor func testCountsItemsAndNotes() throws {
    let context = try makeContext()
    let checklist = makeChecklist(
      in: context,
      name: "Camping",
      notes: "four nights",
      items: [("Tent", "the green one"), ("Stove", nil), ("Matches", "")]
    )

    let properties = checklist.analyticsViewedProperties

    XCTAssertEqual(properties[AnalyticsProperty.checklistName] as? String, "Camping")
    XCTAssertEqual(properties[AnalyticsProperty.notesLength] as? Int, "four nights".count)
    XCTAssertEqual(properties[AnalyticsProperty.itemsCount] as? Int, 3)
    XCTAssertEqual(
      properties[AnalyticsProperty.itemsWithNotesCount] as? Int,
      1,
      "An empty-string note is not a note."
    )
  }

  @MainActor func testAbsentNotesLengthIsZeroNotNil() throws {
    let context = try makeContext()
    let checklist = makeChecklist(in: context, name: "Groceries", notes: nil)

    let properties = checklist.analyticsViewedProperties

    XCTAssertEqual(properties[AnalyticsProperty.notesLength] as? Int, 0)
    XCTAssertEqual(properties[AnalyticsProperty.itemsCount] as? Int, 0)
    XCTAssertEqual(properties[AnalyticsProperty.itemsWithNotesCount] as? Int, 0)
  }

  @MainActor func testLongNameIsTruncated() throws {
    let context = try makeContext()
    let checklist = makeChecklist(in: context, name: String(repeating: "n", count: 300))

    let name = checklist.analyticsViewedProperties[AnalyticsProperty.checklistName] as? String

    XCTAssertEqual(name?.count, AnalyticsText.maximumLength)
  }

  /// The deny-list, asserted directly: item names and every kind of note text must be absent from
  /// the payload entirely, not merely unread by the current dashboard queries.
  @MainActor func testNoItemNamesOrNoteTextIsIncluded() throws {
    let context = try makeContext()
    let checklist = makeChecklist(
      in: context,
      name: "Trip",
      notes: "SECRET_CHECKLIST_NOTE",
      items: [("SECRET_ITEM_NAME", "SECRET_ITEM_NOTE")]
    )

    let rendered = checklist.analyticsViewedProperties
      .map { "\($0.key)=\(String(describing: $0.value))" }
      .joined(separator: "&")

    XCTAssertFalse(rendered.contains("SECRET_ITEM_NAME"))
    XCTAssertFalse(rendered.contains("SECRET_ITEM_NOTE"))
    XCTAssertFalse(rendered.contains("SECRET_CHECKLIST_NOTE"))
    XCTAssertTrue(rendered.contains("Trip"), "The checklist name is the one allow-listed free text.")
  }

  // MARK: - Orientation

  @MainActor func testPortraitOrientationsMapToPortrait() {
    XCTAssertEqual(orientationAnalyticsValue(.portrait), "portrait")
    XCTAssertEqual(orientationAnalyticsValue(.portraitUpsideDown), "portrait")
  }

  @MainActor func testLandscapeOrientationsMapToLandscape() {
    XCTAssertEqual(orientationAnalyticsValue(.landscapeLeft), "landscape")
    XCTAssertEqual(orientationAnalyticsValue(.landscapeRight), "landscape")
  }

  /// Laying the device flat fires the same notification as a real rotation but says nothing about
  /// how the app is being held, so it must produce no event at all.
  @MainActor func testFlatAndUnknownOrientationsAreDropped() {
    XCTAssertNil(orientationAnalyticsValue(.faceUp))
    XCTAssertNil(orientationAnalyticsValue(.faceDown))
    XCTAssertNil(orientationAnalyticsValue(.unknown))
  }

  // MARK: - Cohort bucketing

  @MainActor func testChecklistsCountBucketBoundaries() {
    XCTAssertEqual(checklistsCountBucket(0), "0")
    XCTAssertEqual(checklistsCountBucket(1), "1")
    XCTAssertEqual(checklistsCountBucket(2), "2-3")
    XCTAssertEqual(checklistsCountBucket(3), "2-3")
    XCTAssertEqual(checklistsCountBucket(4), "4-7")
    XCTAssertEqual(checklistsCountBucket(7), "4-7")
    XCTAssertEqual(checklistsCountBucket(8), "8+")
    XCTAssertEqual(checklistsCountBucket(999), "8+")
  }
}
