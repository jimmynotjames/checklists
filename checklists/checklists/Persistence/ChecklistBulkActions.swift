//
//  ChecklistBulkActions.swift
//  checklists
//

import Foundation
import SwiftData

/// The Checklists screen's multi-checklist actions: its Edit mode toolbar, and Reset All.
extension ModelContext {
  /// Deletes every checklist in `ids` with a single save.
  ///
  /// Resolved by `id` at call time rather than handed model references, because the confirmation
  /// alert is answered asynchronously and a sync merge can remove a checklist while it is up.
  /// - Returns: how many were found and deleted.
  @discardableResult
  func deleteChecklists(ids: Set<String>) -> Int {
    delete(found: ids.compactMap { checklist(id: $0) })
  }

  /// Deletes exactly these records, and never a different record that shares one's `id`.
  /// - Returns: how many were found and deleted.
  @discardableResult
  func deleteChecklists(_ persistentIDs: Set<PersistentIdentifier>) -> Int {
    delete(found: persistentIDs.compactMap { checklist($0) })
  }

  private func delete(found: [Checklist]) -> Int {
    // The items go with each one: the relationship's cascade delete rule handles that.
    for checklist in found {
      delete(checklist)
    }
    if !found.isEmpty {
      saveChangesIgnoringFailure(operation: .delete)
    }
    return found.count
  }

  /// Duplicates every checklist in `ids`, each copy landing directly after its source.
  ///
  /// One save per copy, as `duplicate(checklist:among:)` does. The list is re-fetched before each
  /// copy so its name is checked against the copies made earlier in the same batch; two selected
  /// lists sharing a name would otherwise both produce "… copy". Stops at the first failed save,
  /// which `saveChanges` has already reported; copies made before it stay.
  /// - Returns: how many copies were made.
  @discardableResult
  func duplicateChecklists(ids: Set<String>) -> Int {
    guard let sources = try? fetchChecklistsSorted().filter({ ids.contains($0.id) }) else { return 0 }
    var copied = 0
    for source in sources {
      do {
        try duplicate(checklist: source, among: fetchChecklistsSorted())
      } catch {
        break
      }
      copied += 1
    }
    return copied
  }

  /// Unchecks every item in `checklists` with a single save.
  ///
  /// - Returns: how many checklists had an item checked; nothing was saved when it is `0`.
  @discardableResult
  func resetChecklists(_ checklists: [Checklist]) -> Int {
    let now = Date.now
    var resetCount = 0
    // The `where` call is the reset itself, not a filter — SwiftLint's `for_where` requires this
    // shape. Only a list that had something to reset is dated.
    for checklist in checklists where checklist.uncheckAllItems() {
      checklist.recordUpdate(at: now)
      resetCount += 1
    }
    if resetCount > 0 {
      saveChangesIgnoringFailure(operation: .itemUpdate)
    }
    return resetCount
  }
}

/// A one-step reorder of a checklist or an item, offered to assistive technologies, which cannot
/// drag.
///
/// Free of SwiftData so the edge rules can be tested without a container.
nonisolated enum ChecklistMoveAction: CaseIterable {
  case up
  case down
  case top
  case bottom

  /// The index to hand `ModelContext.move(checklist:among:to:)` or `move(item:among:to:)`, which
  /// count positions after the moved row is taken out; `nil` when the move would go nowhere.
  func destination(from index: Int, count: Int) -> Int? {
    let last = count - 1
    switch self {
    case .up: return index > 0 ? index - 1 : nil
    case .down: return index < last ? index + 1 : nil
    case .top: return index > 0 ? 0 : nil
    case .bottom: return index < last ? last : nil
    }
  }
}

/// Where VoiceOver goes after a row is deleted, on either list screen.
///
/// Free of SwiftData, like `ChecklistMoveAction`, so the edge rules can be tested without a
/// container.
nonisolated enum DeletionFocus {
  /// The row that slid into the deleted row's place, else the row above it, counted among the rows
  /// left; `nil` when none are left.
  static func neighbourIndex(afterRemoving index: Int, remainingCount: Int) -> Int? {
    guard remainingCount > 0 else { return nil }
    return min(index, remainingCount - 1)
  }

  /// The id among `ids` that VoiceOver goes to once the one at `index` is deleted; `nil` when it was
  /// the only one.
  static func neighbourID(afterRemoving index: Int, from ids: [String]) -> String? {
    neighbourIndex(afterRemoving: index, remainingCount: ids.count - 1).map { ids[$0 >= index ? $0 + 1 : $0] }
  }
}
