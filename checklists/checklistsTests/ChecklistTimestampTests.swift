//
//  ChecklistTimestampTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing
import UIKit

/// Covers the two history stamps on `Checklist` and the rules behind them, which deliberately
/// differ: `lastUpdated` records an *action* (an item's checked state changed, and nothing else),
/// while `lastCompleted` records a *state transition* (the list became complete, however it got
/// there). See core-docs/persistence-design.md §Model.
///
/// The negative cases carry most of the weight here. Nothing about renaming a checklist visibly
/// "fails" if it starts stamping `lastUpdated`, so those tests are the only thing standing between
/// the narrow definition and a slow drift back to "any write counts".
///
/// No isolation annotation — AGENTS.md §"Concurrency".
@Suite("Checklist update and completion timestamps")
struct ChecklistTimestampTests {
  private let updatedAt = Date(timeIntervalSinceReferenceDate: 1000.0)
  private let completedAt = Date(timeIntervalSinceReferenceDate: 2000.0)
  private let laterAt = Date(timeIntervalSinceReferenceDate: 3000.0)

  /// A checklist with `itemCount` items, the first `checkedCount` of them checked.
  private func makeChecklist(
    itemCount: Int,
    checkedCount: Int = 0,
    in context: ModelContext
  ) throws -> Checklist {
    let checklist = Checklist(name: "Packing", sortKey: 1.0)
    context.insert(checklist)
    for index in 0 ..< itemCount {
      let item = Item(name: "Item \(index)", sortKey: Double(index + 1))
      item.status = index < checkedCount ? .checked : .unchecked
      context.insert(item)
      item.checklist = checklist
    }
    try context.saveChanges(operation: .sampleSeed)
    return checklist
  }

  // MARK: - Updates

  @Test("a checkbox tap stamps lastUpdated")
  func checkboxTapStampsUpdate() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, in: context)

    let wasComplete = checklist.isComplete
    checklist.items[0].toggleStatus()
    context.saveStatusChange(to: checklist, wasComplete: wasComplete, at: updatedAt)

    #expect(checklist.lastUpdated == updatedAt)
    #expect(checklist.lastCompleted == nil)
  }

  @Test("Reset stamps lastUpdated, because unchecking everything is still a status change")
  func resetStampsUpdate() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, checkedCount: 3, in: context)

    let wasComplete = checklist.isComplete
    checklist.uncheckAllItems()
    context.saveStatusChange(to: checklist, wasComplete: wasComplete, at: updatedAt)

    #expect(checklist.lastUpdated == updatedAt)
  }

  @Test("renaming a checklist leaves both stamps alone")
  func renamingChecklistDoesNotStamp() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, in: context)

    checklist.name = "Renamed"
    context.saveChangesIgnoringFailure(operation: .checklistEdit)

    #expect(checklist.lastUpdated == nil)
    #expect(checklist.lastCompleted == nil)
  }

  @Test("editing checklist notes leaves both stamps alone")
  func editingNotesDoesNotStamp() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, in: context)

    checklist.notes = "Bring the good suitcase"
    context.saveChangesIgnoringFailure(operation: .checklistEdit)

    #expect(checklist.lastUpdated == nil)
    #expect(checklist.lastCompleted == nil)
  }

  @Test("renaming an item leaves both stamps alone")
  func renamingItemDoesNotStamp() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, in: context)

    checklist.items[0].name = "Renamed"
    context.saveChangesIgnoringFailure(operation: .itemEdit)

    #expect(checklist.lastUpdated == nil)
    #expect(checklist.lastCompleted == nil)
  }

  @Test("inserting an item leaves both stamps alone")
  func insertingItemDoesNotStamp() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, in: context)

    try context.insert(item: Item(name: "Sunscreen"), at: 1, in: checklist)

    #expect(checklist.lastUpdated == nil)
    #expect(checklist.lastCompleted == nil)
  }

  @Test("reordering items leaves both stamps alone")
  func reorderingDoesNotStamp() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, in: context)

    let items = checklist.items
    try context.move(item: items[0], among: items, to: 2)

    #expect(checklist.lastUpdated == nil)
    #expect(checklist.lastCompleted == nil)
  }

  // MARK: - Completions

  @Test("checking the last unchecked item stamps lastCompleted")
  func finalCheckStampsCompletion() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, checkedCount: 2, in: context)

    let wasComplete = checklist.isComplete
    checklist.items[2].toggleStatus()
    context.saveStatusChange(to: checklist, wasComplete: wasComplete, at: completedAt)

    #expect(checklist.lastCompleted == completedAt)
    #expect(checklist.lastUpdated == completedAt)
  }

  @Test("checking a non-final item does not stamp lastCompleted")
  func partialCheckDoesNotStampCompletion() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, checkedCount: 1, in: context)

    let wasComplete = checklist.isComplete
    checklist.items[1].toggleStatus()
    context.saveStatusChange(to: checklist, wasComplete: wasComplete, at: updatedAt)

    #expect(checklist.lastUpdated == updatedAt)
    #expect(checklist.lastCompleted == nil)
  }

  @Test("unchecking from complete neither stamps nor clears lastCompleted")
  func uncheckingKeepsCompletion() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, checkedCount: 3, in: context)
    checklist.recordCompletion(at: completedAt)

    let wasComplete = checklist.isComplete
    checklist.items[0].toggleStatus()
    context.saveStatusChange(to: checklist, wasComplete: wasComplete, at: laterAt)

    #expect(checklist.lastCompleted == completedAt)
    #expect(checklist.lastUpdated == laterAt)
  }

  @Test("a list already complete is not restamped by further ticking")
  func alreadyCompleteIsNotRestamped() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 1, checkedCount: 1, in: context)
    checklist.recordCompletion(at: completedAt)

    // Re-checking an already-checked item: still complete before, still complete after.
    let wasComplete = checklist.isComplete
    checklist.items[0].status = .checked
    context.saveStatusChange(to: checklist, wasComplete: wasComplete, at: laterAt)

    #expect(checklist.lastCompleted == completedAt)
  }

  @Test("deleting every item does not complete the list")
  func deletingEveryItemDoesNotComplete() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 2, in: context)

    let wasComplete = checklist.isComplete
    for item in checklist.items {
      context.delete(item)
    }
    context.saveDeletion(from: checklist, wasComplete: wasComplete, at: completedAt)

    #expect(checklist.lastCompleted == nil)
  }

  @Test("adding an item to a complete list clears nothing")
  func addingItemKeepsCompletion() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 2, checkedCount: 2, in: context)
    checklist.recordUpdate(at: updatedAt)
    checklist.recordCompletion(at: completedAt)

    try context.insert(item: Item(name: "One more thing"), at: 2, in: checklist)

    #expect(checklist.isComplete == false)
    #expect(checklist.lastCompleted == completedAt)
    #expect(checklist.lastUpdated == updatedAt)
  }

  @Test("Reset clears the checks but not the completion record")
  func resetKeepsCompletion() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 2, checkedCount: 2, in: context)
    checklist.recordCompletion(at: completedAt)

    let wasComplete = checklist.isComplete
    checklist.uncheckAllItems()
    context.saveStatusChange(to: checklist, wasComplete: wasComplete, at: laterAt)

    #expect(checklist.percentageComplete == 0.0)
    #expect(checklist.lastCompleted == completedAt)
  }

  @Test("completing a second time overwrites with the later date")
  func recompletionOverwrites() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 2, checkedCount: 2, in: context)
    checklist.recordCompletion(at: completedAt)

    // Reset, then work back up to complete.
    checklist.uncheckAllItems()
    let wasComplete = checklist.isComplete
    for item in checklist.items {
      item.status = .checked
    }
    context.saveStatusChange(to: checklist, wasComplete: wasComplete, at: laterAt)

    #expect(checklist.lastCompleted == laterAt)
  }

  // MARK: - Where the two rules diverge

  @Test("deleting the last unchecked item completes the list without counting as an update")
  func deletingLastUncheckedItemCompletesOnly() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, checkedCount: 2, in: context)
    checklist.recordUpdate(at: updatedAt)

    let wasComplete = checklist.isComplete
    context.delete(checklist.items[2])
    context.saveDeletion(from: checklist, wasComplete: wasComplete, at: completedAt)

    #expect(checklist.isComplete)
    #expect(checklist.lastCompleted == completedAt)
    // Deleting is an edit, so the update stamp stays where the last tick left it.
    #expect(checklist.lastUpdated == updatedAt)
  }

  @Test("deleting an item that leaves work outstanding stamps nothing")
  func deletingWithWorkLeftStampsNothing() throws {
    let context = try TestModelContainer.makeContext()
    let checklist = try makeChecklist(itemCount: 3, checkedCount: 1, in: context)

    let wasComplete = checklist.isComplete
    context.delete(checklist.items[2])
    context.saveDeletion(from: checklist, wasComplete: wasComplete, at: completedAt)

    #expect(checklist.lastUpdated == nil)
    #expect(checklist.lastCompleted == nil)
  }

  // MARK: - Caption

  @Test("a checklist with no history has no caption")
  func captionIsEmptyWithoutHistory() {
    let checklist = Checklist(name: "Packing")
    #expect(ChecklistHistoryCaption.lines(for: checklist, isNewChecklist: false).isEmpty)
  }

  @Test("a checklist being created shows no caption even when it has dates")
  func captionIsEmptyForNewChecklist() {
    let checklist = Checklist(name: "Packing")
    checklist.recordUpdate(at: updatedAt)
    checklist.recordCompletion(at: completedAt)
    #expect(ChecklistHistoryCaption.lines(for: checklist, isNewChecklist: true).isEmpty)
  }

  @Test("an updated but never completed checklist shows one line")
  func captionShowsUpdatedOnly() {
    let checklist = Checklist(name: "Packing")
    checklist.recordUpdate(at: updatedAt)

    let lines = ChecklistHistoryCaption.lines(for: checklist, isNewChecklist: false)
    #expect(lines.count == 1)
    #expect(lines.first?.hasPrefix("Updated ") == true)
  }

  @Test("the stated caption height covers what the label actually renders", arguments: [1, 2])
  func captionHeightCoversRenderedLabel(lineCount: Int) {
    // The header's height is a chain of constants — `height(forLineCount:)` is what the layout
    // believes the caption needs, and the table reserves space from that. If it ever undershoots
    // what `configure` renders, the table lays the first item underneath the header and the list
    // looks clipped. Nothing in the UI tests can see that: XCUITest reports Auto Layout positions,
    // not the height the table reserved.
    let lines = Array(["Updated Today at 3:42 PM", "Last completed Yesterday at 9:15 AM"].prefix(lineCount))
    let label = UILabel()
    ChecklistHistoryCaption.configure(label, with: lines)

    // Roughly the header's content width on the narrowest supported phone.
    let rendered = label.sizeThatFits(CGSize(width: 327.0, height: .greatestFiniteMagnitude)).height
    #expect(ChecklistHistoryCaption.height(forLineCount: lineCount) >= rendered)
  }

  @Test("a completed checklist shows both lines, updated first")
  func captionShowsBothLinesInOrder() {
    let checklist = Checklist(name: "Packing")
    checklist.recordUpdate(at: updatedAt)
    checklist.recordCompletion(at: completedAt)

    // The prefixes are asserted, not the formatted dates, which follow the test runner's locale.
    let lines = ChecklistHistoryCaption.lines(for: checklist, isNewChecklist: false)
    #expect(lines.count == 2)
    #expect(lines.first?.hasPrefix("Updated ") == true)
    #expect(lines.last?.hasPrefix("Last completed ") == true)
  }
}
