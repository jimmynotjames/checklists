//
//  ChecklistDuplication.swift
//  checklists
//

import Foundation
import SwiftData

extension ModelContext {
  /// Deep-copies `source` and places the copy directly after it in the user's ordering.
  ///
  /// - Parameter siblings: every checklist in display order, **including** `source`.
  /// - Returns: the copy, inserted and saved.
  @discardableResult
  func duplicate(checklist source: Checklist, among siblings: [Checklist]) throws -> Checklist {
    let copy = Checklist(
      name: ChecklistCopyNaming.name(forCopyOf: source.name, existingNames: Set(siblings.map(\.name))),
      notes: source.notes
    )
    // `lastUpdated` and `lastCompleted` stay nil, which is what `Checklist.init` leaves them: both
    // record something that happened to the original, and nothing has happened to this copy yet.
    insert(copy)

    // Blank rows are the scratch item the detail screen seeds and trims, not tasks, so a copy does
    // not inherit an abandoned one. Item keys are re-issued rather than copied, matching
    // `LegacyRealmImporter`: `source.items` is already sorted, so spacing them afresh preserves the
    // order and leaves the copy evenly spaced room to reorder.
    var sortKey = SortKeyReorder.step
    for item in source.items where !item.isBlank {
      // Status is deliberately not carried over — a duplicate has never been run. `Item.init`
      // already leaves it unchecked, so that is the absence of a line rather than a line.
      let copiedItem = Item(name: item.name, notes: item.notes, sortKey: sortKey)
      insert(copiedItem)
      // Child side only; SwiftData maintains `itemsStorage` as the inverse. See `Reordering`.
      copiedItem.checklist = copy
      sortKey += SortKeyReorder.step
    }

    // `nil` only if the caller passed a list `source` is not in; appending is the safe response.
    let index = siblings.firstIndex { $0 === source }.map { $0 + 1 } ?? siblings.count
    // A single save for the whole graph. Going through `insert(checklist:at:among:)` and
    // `insert(item:at:in:)` instead would be one save per record — 31 of them for a 30-item list.
    do {
      try placeAndSave(copy, at: index, among: siblings, restoringSortKeysOf: siblings) {
        try saveChanges(operation: .checklistEdit)
      }
    } catch {
      // `placeAndSave` puts the siblings' keys back; the half-built copy is this method's to undo.
      // Left in, it would render in the list as a checklist that was never written to disk.
      delete(copy) // The copied items go with it, by the cascade rule.
      throw error
    }
    return copy
  }
}

/// Names the copy a duplication produces.
///
/// Free of SwiftData so the collision rules can be tested without a container, for the same reason
/// `SortKeyReorder` is.
nonisolated enum ChecklistCopyNaming {
  /// - Parameter existingNames: the names already in use, including `sourceName`'s.
  static func name(forCopyOf sourceName: String, existingNames: Set<String>) -> String {
    // A checklist saved without a name reads as "untitled checklist" everywhere else; " copy" on
    // its own would not name anything.
    let base = sourceName.isEmpty ? CommonStrings.defaultChecklistName : sourceName

    var candidate = String(
      localized: "checklists.duplicate.name",
      defaultValue: "\(base) copy",
      comment: """
      Name given to a duplicated checklist. The placeholder is the original's name. Stored as the \
      new checklist's name, so it keeps whatever language the device had when it was made — it is \
      data, not a label, and is never re-translated afterwards. Pair it with \
      checklists.duplicate.nameNumbered, which disambiguates a second copy. Keep the added word \
      short: it sits after a name the user chose.
      """
    )
    // Only an exact clash is disambiguated. The suffix is never parsed back out of a name, so a
    // copy of a copy is "… copy copy" rather than "… copy 2" — recognising the suffix would mean
    // matching translated text in 50 locales against names the user is free to edit.
    var number = 2
    while existingNames.contains(candidate) {
      candidate = String(
        localized: "checklists.duplicate.nameNumbered",
        defaultValue: "\(base) copy \(number)",
        comment: """
        Name given to a duplicated checklist when checklists.duplicate.name is already taken. \
        The first placeholder is the original's name, the second a counter starting at 2. Stored \
        as the new checklist's name, so it is data and is never re-translated. Match the wording \
        of checklists.duplicate.name exactly, or two copies of one list will not read as a series.
        """
      )
      number += 1
    }
    return candidate
  }
}
