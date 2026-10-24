//
//  ChecklistPDFSnapshot.swift
//  checklists
//

import Foundation

/// Everything an exported PDF shows, copied out of the checklist when Export is tapped.
///
/// A value, so the PDF is of the checklist as it was at that moment, and so nothing downstream
/// touches SwiftData models.
nonisolated struct ChecklistPDFSnapshot: Equatable {
  struct Row: Equatable {
    let name: String
    let notes: String?
    let isChecked: Bool
  }

  /// Never empty: an unnamed checklist carries the app's untitled fallback.
  let title: String
  let date: Date
  /// Trimmed; empty when there is none, and then the PDF has no Header.
  let header: String
  let checklistNotes: String?
  let rows: [Row]
  /// The app's language direction, not the text's: a Hebrew-language app mirrors the whole page,
  /// checkboxes included, even for a checklist written in English.
  let isRightToLeft: Bool
  let locale: Locale
  let timeZone: TimeZone
  let paperSize: PaperSize

  init(
    title: String,
    date: Date,
    header: String,
    checklistNotes: String?,
    rows: [Row],
    isRightToLeft: Bool,
    locale: Locale = .current,
    timeZone: TimeZone = .current,
    paperSize: PaperSize = PaperSize.forRegion(Locale.current.region?.identifier),
  ) {
    self.title = title
    self.date = date
    self.header = HeaderText.normalized(header)
    self.checklistNotes = Self.nonEmpty(checklistNotes)
    self.rows = rows
    self.isRightToLeft = isRightToLeft
    self.locale = locale
    self.timeZone = timeZone
    self.paperSize = paperSize
  }

  /// Reads the checklist in display order. Blank scratch rows are left out: they are not tasks,
  /// and an empty checkbox on a receipt would read as skipped work.
  @MainActor
  static func make(
    from checklist: Checklist,
    date: Date,
    header: String,
    isRightToLeft: Bool,
    locale: Locale = .current,
    timeZone: TimeZone = .current,
    paperSize: PaperSize = PaperSize.forRegion(Locale.current.region?.identifier),
  ) -> ChecklistPDFSnapshot {
    let rows = checklist.items.filter { !$0.isBlank }.map { item in
      Row(name: item.name, notes: nonEmpty(item.notes), isChecked: item.status == .checked)
    }
    return ChecklistPDFSnapshot(
      title: checklist.name.isEmpty ? CommonStrings.defaultChecklistName : checklist.name,
      date: date,
      header: header,
      checklistNotes: checklist.notes,
      rows: rows,
      isRightToLeft: isRightToLeft,
      locale: locale,
      timeZone: timeZone,
      paperSize: paperSize,
    )
  }

  private static func nonEmpty(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
    return trimmed
  }
}
