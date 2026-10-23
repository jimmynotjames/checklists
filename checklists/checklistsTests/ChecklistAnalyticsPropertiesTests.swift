//
//  ChecklistAnalyticsPropertiesTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import Testing

/// Covers the two pure mappings that feed events: `Checklist.analyticsViewedProperties` and
/// `orientationAnalyticsValue`.
///
/// `analyticsViewedProperties` is also where this app's PII boundary is drawn in code
/// (analytics-spec.md §Privacy), so the negative assertions below — that no note text and no item name
/// appears anywhere in the payload — are the point of the class, not padding.
@Suite("Checklist analytics property mapping")
struct ChecklistAnalyticsPropertiesTests {
  private func makeChecklist(
    in context: ModelContext,
    name: String,
    notes: String? = nil,
    items: [(name: String, notes: String?)] = [],
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

  @Test("checklist analytics properties count items and notes")
  func countsItemsAndNotes() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = makeChecklist(
      in: context,
      name: "Camping",
      notes: "four nights",
      items: [("Tent", "the green one"), ("Stove", nil), ("Matches", "")],
    )

    let properties = checklist.analyticsViewedProperties

    #expect(properties[AnalyticsProperty.checklistName] as? String == "Camping")
    #expect(properties[AnalyticsProperty.notesLength] as? Int == "four nights".count)
    #expect(properties[AnalyticsProperty.itemsCount] as? Int == 3)
    #expect(
      properties[AnalyticsProperty.itemsWithNotesCount] as? Int == 1,
      "An empty-string note is not a note.",
    )
  }

  @Test("absent notes report a notes length of zero, not nil")
  func absentNotesLengthIsZeroNotNil() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = makeChecklist(in: context, name: "Groceries", notes: nil)

    let properties = checklist.analyticsViewedProperties

    #expect(properties[AnalyticsProperty.notesLength] as? Int == 0)
    #expect(properties[AnalyticsProperty.itemsCount] as? Int == 0)
    #expect(properties[AnalyticsProperty.itemsWithNotesCount] as? Int == 0)
  }

  @Test("an overlong checklist name is truncated")
  func longNameIsTruncated() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = makeChecklist(in: context, name: String(repeating: "n", count: 300))

    let name = checklist.analyticsViewedProperties[AnalyticsProperty.checklistName] as? String

    #expect(name?.count == AnalyticsText.maximumLength)
  }

  /// The deny-list, asserted directly: item names and every kind of note text must be absent from
  /// the payload entirely, not merely unread by the current dashboard queries.
  @Test("item names and note text are excluded from analytics properties")
  func noItemNamesOrNoteTextIsIncluded() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = makeChecklist(
      in: context,
      name: "Trip",
      notes: "SECRET_CHECKLIST_NOTE",
      items: [("SECRET_ITEM_NAME", "SECRET_ITEM_NOTE")],
    )

    let rendered = checklist.analyticsViewedProperties
      .map { "\($0.key)=\(String(describing: $0.value))" }
      .joined(separator: "&")

    #expect(!rendered.contains("SECRET_ITEM_NAME"))
    #expect(!rendered.contains("SECRET_ITEM_NOTE"))
    #expect(!rendered.contains("SECRET_CHECKLIST_NOTE"))
    #expect(rendered.contains("Trip"), "The checklist name is the one allow-listed free text.")
  }

  // MARK: - Orientation

  @Test("portrait orientations map to portrait")
  func portraitOrientationsMapToPortrait() {
    #expect(orientationAnalyticsValue(.portrait) == "portrait")
    #expect(orientationAnalyticsValue(.portraitUpsideDown) == "portrait")
  }

  @Test("landscape orientations map to landscape")
  func landscapeOrientationsMapToLandscape() {
    #expect(orientationAnalyticsValue(.landscapeLeft) == "landscape")
    #expect(orientationAnalyticsValue(.landscapeRight) == "landscape")
  }

  /// Laying the device flat fires the same notification as a real rotation but says nothing about
  /// how the app is being held, so it must produce no event at all.
  @Test("flat and unknown orientations are dropped")
  func flatAndUnknownOrientationsAreDropped() {
    #expect(orientationAnalyticsValue(.faceUp) == nil)
    #expect(orientationAnalyticsValue(.faceDown) == nil)
    #expect(orientationAnalyticsValue(.unknown) == nil)
  }

  // MARK: - Cohort bucketing

  @Test("checklistsCountBucket boundaries")
  func checklistsCountBucketBoundaries() {
    #expect(checklistsCountBucket(0) == "0")
    #expect(checklistsCountBucket(1) == "1")
    #expect(checklistsCountBucket(2) == "2-3")
    #expect(checklistsCountBucket(3) == "2-3")
    #expect(checklistsCountBucket(4) == "4-7")
    #expect(checklistsCountBucket(7) == "4-7")
    #expect(checklistsCountBucket(8) == "8+")
    #expect(checklistsCountBucket(999) == "8+")
  }
}
