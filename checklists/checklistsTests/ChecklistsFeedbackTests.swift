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

/// The confirmation alerts name what they act on, so VoiceOver reads more than "This cannot be undone".
@Suite("Checklists list confirmation titles")
struct ChecklistsConfirmationTitleTests {
  @Test("the delete title names the checklist")
  func deleteTitleNamesTheChecklist() {
    let name = String("Weekend packing")
    #expect(ChecklistsView.deleteConfirmationTitle(name: name).contains(name))
  }

  @Test("a blank name reads as the default checklist name")
  func blankNameFallsBack() {
    #expect(
      ChecklistsView.deleteConfirmationTitle(name: "")
        == ChecklistsView.deleteConfirmationTitle(name: CommonStrings.defaultChecklistName)
    )
  }

  @Test("bulk titles carry the count and tell delete from reset")
  func bulkTitlesCarryTheCount() {
    let delete = ChecklistsView.bulkConfirmationTitle(for: .delete, count: 3)
    let reset = ChecklistsView.bulkConfirmationTitle(for: .reset, count: 3)
    #expect(delete.contains("3"))
    #expect(reset.contains("3"))
    #expect(delete != reset)
  }
}
