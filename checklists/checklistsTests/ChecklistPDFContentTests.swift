//
//  ChecklistPDFContentTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Testing
import UIKit

/// Covers what an exported PDF contains: the snapshot taken from the checklist, and the text laid
/// out from it.
@Suite("Checklist PDF content")
struct ChecklistPDFContentTests {
  private func makeChecklist(name: String, notes: String? = nil, items: [ChecklistPDFSnapshot.Row]) throws -> (ModelContext, Checklist) {
    let context = try TestModelContainer.makeContext()
    let checklist = Checklist(name: name, notes: notes)
    context.insert(checklist)
    for (offset, entry) in items.enumerated() {
      let item = Item(name: entry.name, notes: entry.notes, sortKey: Double(offset + 1))
      item.status = entry.isChecked ? .checked : .unchecked
      context.insert(item)
      item.checklist = checklist
    }
    return (context, checklist)
  }

  private func snapshot(notes: String? = nil, rows: [ChecklistPDFSnapshot.Row] = [], isRightToLeft: Bool = false) -> ChecklistPDFSnapshot {
    ChecklistPDFSnapshot(title: "Quality check", checklistNotes: notes, rows: rows, isRightToLeft: isRightToLeft, paperSize: .a4)
  }

  // MARK: - Snapshot

  @Test("rows follow the checklist's order and keep their state and notes")
  func rowsFollowTheChecklist() throws {
    let (_, checklist) = try makeChecklist(name: "Quality check", items: [
      .init(name: "Shut off water", notes: nil, isChecked: true),
      .init(name: "Check heater", notes: "Not applicable: no heater.", isChecked: false),
    ])

    let snapshot = ChecklistPDFSnapshot.make(from: checklist, isRightToLeft: false)

    #expect(snapshot.rows == [
      .init(name: "Shut off water", notes: nil, isChecked: true),
      .init(name: "Check heater", notes: "Not applicable: no heater.", isChecked: false),
    ])
  }

  /// A scratch row is not a task, and an empty box on a receipt would read as skipped work.
  @Test("blank scratch rows are left out")
  func blankRowsAreLeftOut() throws {
    let (_, checklist) = try makeChecklist(name: "Quality check", items: [.init(name: "Shut off water", notes: nil, isChecked: true), .init(name: "", notes: nil, isChecked: false)])

    let snapshot = ChecklistPDFSnapshot.make(from: checklist, isRightToLeft: false)

    #expect(snapshot.rows.map(\.name) == ["Shut off water"])
  }

  @Test("an unnamed checklist is titled with the untitled name")
  func unnamedChecklistUsesTheFallback() throws {
    let (_, checklist) = try makeChecklist(name: "", items: [])

    let snapshot = ChecklistPDFSnapshot.make(from: checklist, isRightToLeft: false)

    #expect(snapshot.title == CommonStrings.defaultChecklistName)
  }

  @Test("whitespace-only notes count as none")
  func whitespaceCountsAsNone() throws {
    let (_, checklist) = try makeChecklist(name: "Quality check", notes: " \n", items: [.init(name: "Shut off water", notes: "  ", isChecked: false)])

    let snapshot = ChecklistPDFSnapshot.make(from: checklist, isRightToLeft: false)

    #expect(snapshot.checklistNotes == nil)
    #expect(snapshot.rows.first?.notes == nil)
  }

  // MARK: - Layout

  @Test("the text runs name, checklist notes, then items")
  func textRunsInOrder() {
    let text = ChecklistPDFContent.attributedString(
      for: snapshot(notes: "Acme Plumbing, licence 12345", rows: [.init(name: "Shut off water", notes: "Done at the street.", isChecked: true)]),
      contentWidth: 480,
    ).string

    let order = ["Quality check", "Acme Plumbing, licence 12345", "Shut off water", "Done at the street."]
      .map { text.range(of: $0)?.lowerBound }
    #expect(order.allSatisfy { $0 != nil })
    #expect(order.compactMap(\.self) == order.compactMap(\.self).sorted())
  }

  /// One per item for the checkbox and one for the gap after it, plus the divider.
  @Test("every item gets a checkbox")
  func everyItemGetsACheckbox() {
    let rows: [ChecklistPDFSnapshot.Row] = [.init(name: "A", notes: nil, isChecked: true), .init(name: "B", notes: nil, isChecked: false)]
    let text = ChecklistPDFContent.attributedString(for: snapshot(rows: rows), contentWidth: 480)

    var attachments = 0
    text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length)) { value, _, _ in
      if value != nil {
        attachments += 1
      }
    }
    #expect(attachments == rows.count * 2 + 1)
  }

  @Test("a right-to-left app lays the whole page out right to left")
  func rightToLeftSetsTheBaseDirection() {
    let text = ChecklistPDFContent.attributedString(for: snapshot(rows: [.init(name: "A", notes: nil, isChecked: false)], isRightToLeft: true), contentWidth: 480)

    var directions: Set<NSWritingDirection> = []
    text.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: text.length)) { value, _, _ in
      if let style = value as? NSParagraphStyle {
        directions.insert(style.baseWritingDirection)
      }
    }
    #expect(directions == [.rightToLeft])
  }
}
