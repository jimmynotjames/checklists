//
//  ChecklistViewLifecycleTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing
import UIKit

/// Covers what loading and leaving the checklist screen writes to the store.
/// `.serialized` — same `RemoteChangeObserver` reason as `ChecklistMenuActionTests`.
@Suite("Checklist screen lifecycle", .serialized)
struct ChecklistViewLifecycleTests {
  // MARK: - The blank scratch row

  /// An empty checklist opens with somewhere to type, and that row is a real persisted `Item`
  /// rather than a placeholder — which is why `viewDidDisappear` has to clean it up again.
  @Test("an empty checklist is seeded with one blank row")
  func emptyChecklistIsSeededWithABlankRow() throws {
    try ChecklistScreenHarness.withController { harness in
      #expect(harness.checklist.items.count == 1)
      #expect(harness.checklist.items[0].isBlank)
      let persisted = try harness.persistedItemNames()
      #expect(persisted == [""], "The scratch row is saved, not just staged.")
      #expect(harness.table.numberOfRows(inSection: 0) == 1)
    }
  }

  @Test("a checklist that already has items is not seeded")
  func populatedChecklistIsNotSeeded() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      #expect(harness.itemNames == ["Milk"])
    }
  }

  // MARK: - Leaving the screen

  /// Blank rows left dangling at the end are tidied away, or every visit to an untouched checklist
  /// would leave another one behind.
  @Test("trailing blank rows are trimmed on leaving")
  func trailingBlankRowsAreTrimmed() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", false), ("", false), ("", false)],
    ) { harness in
      harness.viewController.viewDidDisappear(false)

      #expect(harness.itemNames == ["Milk"])
      let persisted = try harness.persistedItemNames()
      #expect(persisted == ["Milk"], "The trim is saved, not just staged.")
    }
  }

  /// The trim stops at index 0 (`while i > 0`), so whatever sits there survives regardless of how
  /// it got there. Keeping one blank row is the point: the screen would otherwise reopen with
  /// nowhere to type.
  @Test("a lone blank row is kept")
  func loneBlankRowIsKept() throws {
    try ChecklistScreenHarness.withController { harness in
      #expect(harness.checklist.items.count == 1)

      harness.viewController.viewDidDisappear(false)

      #expect(harness.checklist.items.count == 1)
      #expect(harness.checklist.items[0].isBlank)
    }
  }

  /// Only trailing blanks go. A blank between two real items is somewhere the user is mid-thought,
  /// not leftover scratch.
  @Test("a blank row between two items survives")
  func blankRowBetweenItemsSurvives() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", false), ("", false), ("Bread", false)],
    ) { harness in
      harness.viewController.viewDidDisappear(false)

      #expect(harness.itemNames == ["Milk", "", "Bread"])
    }
  }

  /// Two items, so the loop actually runs and has to stop at the last one rather than falling out
  /// of its `while i > 0` bound.
  @Test("a trailing real item stops the trim")
  func trailingRealItemStopsTheTrim() throws {
    try ChecklistScreenHarness.withController(
      items: [("Milk", false), ("Bread", false)],
    ) { harness in
      harness.viewController.viewDidDisappear(false)

      #expect(harness.itemNames == ["Milk", "Bread"])
    }
  }

  /// The case that separates `while i > 0` from "delete every blank": an all-blank list collapses
  /// to one row, not none.
  @Test("an all-blank checklist keeps exactly one row")
  func allBlankChecklistKeepsOneRow() throws {
    try ChecklistScreenHarness.withController(
      items: [("", false), ("", false), ("", false)],
    ) { harness in
      harness.viewController.viewDidDisappear(false)

      #expect(harness.checklist.items.count == 1)
    }
  }

  // MARK: - Committing the header fields

  @Test("the checklist name is saved when the field finishes editing")
  func nameIsSavedOnEndEditing() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      harness.header.nameTextField.text = "Weekly shop"

      harness.viewController.textFieldDidEndEditing(harness.header.nameTextField)

      #expect(harness.checklist.name == "Weekly shop")
      let verification = ModelContext(harness.modelContext.container)
      let saved = try verification.fetchChecklistsSorted().first?.name
      #expect(saved == "Weekly shop")
    }
  }

  /// A checklist saved with the field cleared reads as "untitled" everywhere else, so the blank is
  /// resolved here rather than left for every screen that displays a name.
  @Test("an emptied name falls back to the default")
  func emptiedNameFallsBackToTheDefault() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      harness.header.nameTextField.text = ""

      harness.viewController.textFieldDidEndEditing(harness.header.nameTextField)

      #expect(harness.checklist.name == CommonStrings.defaultChecklistName)
    }
  }

  @Test("checklist notes are saved when the text view finishes editing")
  func notesAreSavedOnEndEditing() throws {
    try ChecklistScreenHarness.withController(items: [("Milk", false)]) { harness in
      harness.header.notesTextView.text = "before Friday"

      harness.viewController.textViewDidEndEditing(harness.header.notesTextView)

      #expect(harness.checklist.notes == "before Friday")
      let verification = ModelContext(harness.modelContext.container)
      let saved = try verification.fetchChecklistsSorted().first?.notes
      #expect(saved == "before Friday")
    }
  }
}
