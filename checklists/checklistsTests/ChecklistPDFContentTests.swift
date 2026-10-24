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
  private let date = Date(timeIntervalSince1970: 1_792_756_800) // 2026-10-23 12:00 UTC

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

  private func snapshot(header: String = "", notes: String? = nil, rows: [ChecklistPDFSnapshot.Row] = [], isRightToLeft: Bool = false) -> ChecklistPDFSnapshot {
    ChecklistPDFSnapshot(
      title: "Quality check",
      date: date,
      header: header,
      checklistNotes: notes,
      rows: rows,
      isRightToLeft: isRightToLeft,
      locale: Locale(identifier: "en_GB"),
      timeZone: TimeZone(identifier: "UTC")!,
      paperSize: .a4,
    )
  }

  // MARK: - Snapshot

  @Test("rows follow the checklist's order and keep their state and notes")
  func rowsFollowTheChecklist() throws {
    let (_, checklist) = try makeChecklist(name: "Quality check", items: [
      .init(name: "Shut off water", notes: nil, isChecked: true),
      .init(name: "Check heater", notes: "Not applicable: no heater.", isChecked: false),
    ])

    let snapshot = ChecklistPDFSnapshot.make(from: checklist, date: date, header: "", isRightToLeft: false)

    #expect(snapshot.rows == [
      .init(name: "Shut off water", notes: nil, isChecked: true),
      .init(name: "Check heater", notes: "Not applicable: no heater.", isChecked: false),
    ])
  }

  /// A scratch row is not a task, and an empty box on a receipt would read as skipped work.
  @Test("blank scratch rows are left out")
  func blankRowsAreLeftOut() throws {
    let (_, checklist) = try makeChecklist(name: "Quality check", items: [.init(name: "Shut off water", notes: nil, isChecked: true), .init(name: "", notes: nil, isChecked: false)])

    let snapshot = ChecklistPDFSnapshot.make(from: checklist, date: date, header: "", isRightToLeft: false)

    #expect(snapshot.rows.map(\.name) == ["Shut off water"])
  }

  @Test("an unnamed checklist is titled with the untitled name")
  func unnamedChecklistUsesTheFallback() throws {
    let (_, checklist) = try makeChecklist(name: "", items: [])

    let snapshot = ChecklistPDFSnapshot.make(from: checklist, date: date, header: "", isRightToLeft: false)

    #expect(snapshot.title == CommonStrings.defaultChecklistName)
  }

  @Test("whitespace-only notes and Header count as none")
  func whitespaceCountsAsNone() throws {
    let (_, checklist) = try makeChecklist(name: "Quality check", notes: " \n", items: [.init(name: "Shut off water", notes: "  ", isChecked: false)])

    let snapshot = ChecklistPDFSnapshot.make(from: checklist, date: date, header: "\n\n ", isRightToLeft: false)

    #expect(snapshot.checklistNotes == nil)
    #expect(snapshot.header.isEmpty)
    #expect(snapshot.rows.first?.notes == nil)
  }

  // MARK: - Layout

  @Test("the text runs name, date, Header, checklist notes, then items")
  func textRunsInOrder() {
    let text = ChecklistPDFContent.attributedString(
      for: snapshot(header: "Acme Plumbing", notes: "Bring washers.", rows: [.init(name: "Shut off water", notes: "Done at the street.", isChecked: true)]),
      contentWidth: 480,
    ).string

    let order = ["Quality check", "Friday", "Acme Plumbing", "Bring washers.", "Shut off water", "Done at the street."]
      .map { text.range(of: $0)?.lowerBound }
    #expect(order.allSatisfy { $0 != nil })
    #expect(order.compactMap(\.self) == order.compactMap(\.self).sorted())
  }

  @Test("an empty Header leaves no Header text and no gap for one")
  func emptyHeaderIsAbsent() {
    let withHeader = ChecklistPDFContent.attributedString(for: snapshot(header: "Acme"), contentWidth: 480)
    let without = ChecklistPDFContent.attributedString(for: snapshot(), contentWidth: 480)

    #expect(without.string.components(separatedBy: "\n").count == withHeader.string.components(separatedBy: "\n").count - 1)
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

  /// Checked by its parts: ICU owns the punctuation and the zone's name, which shift between OS
  /// releases.
  @Test("the date is long and localized, with weekday, time and time zone")
  func dateIsLongAndLocalized() {
    let text = ChecklistPDFContent.dateString(for: snapshot())

    for part in ["Friday", "23 October 2026", "12:00", "GMT"] {
      #expect(text.contains(part), "\(text)")
    }
  }
}
