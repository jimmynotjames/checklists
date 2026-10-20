//
//  ChecklistsFeedbackTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// What the list of checklists tells VoiceOver after a delete or an Edit mode action. Where focus
/// lands in the running view, and when, needs VoiceOver itself; these pin the choices behind it.
@Suite("Checklists list VoiceOver feedback")
struct ChecklistsFeedbackTests {
  @Test(
    "a delete hands VoiceOver to the checklist that slid up, else the one above, else nothing",
    arguments: [
      (0, ["a", "b", "c"], "b" as String?),
      (1, ["a", "b", "c"], "c"),
      (2, ["a", "b", "c"], "b"),
      (0, ["a"], nil),
    ]
  )
  func neighbour(removed index: Int, ids: [String], expected: String?) {
    #expect(DeletionFocus.neighbourID(afterRemoving: index, from: ids) == expected)
  }

  @Test("each Edit mode action has its own announcement, carrying the count")
  func bulkAnnouncements() {
    let announcements = [ChecklistsBulkAction.delete, .duplicate, .reset].map {
      ChecklistsView.bulkAnnouncement(for: $0, count: 3)
    }
    #expect(Set(announcements).count == 3)
    #expect(announcements.allSatisfy { $0.contains("3") })
  }
}
