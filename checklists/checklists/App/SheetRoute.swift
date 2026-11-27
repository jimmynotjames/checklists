//
//  SheetRoute.swift
//  checklists
//

import Foundation

/// Destinations for modal sheet presentation.
///
/// Conforms to `Identifiable` so it binds directly to `.sheet(item:)`.
/// The `newChecklist` case carries the id the new `Checklist` will be created with, so
/// the id is decided at the call site rather than inside the sheet's own view — see
/// `Router.selectedChecklistID` for the rationale on carrying stable ids rather than live model references.
enum SheetRoute: Hashable, Identifiable {
  case settings
  case newChecklist(id: String)
  case analyticsConsent
  /// The destination picker for "Copy Checked Items to…" and "Move Checked Items to…", carrying
  /// the id of the checklist the items are leaving.
  case transferCheckedItems(sourceID: String, mode: CheckedItemsTransferMode)
  /// The create sheet, opened from that picker's New Checklist button on a checklist that already
  /// holds copies of the checked items. Presented exactly like `newChecklist`; the transfer is what
  /// the source screen finishes once the sheet closes (`completeCheckedItemsTransfer`).
  case checkedItemsChecklist(id: String, transfer: CheckedItemsTransfer)

  var id: Self {
    self
  }
}

/// Whether the checked-items picker leaves the originals where they were.
enum CheckedItemsTransferMode: Hashable {
  case copy
  case move
}

/// A copy or move into a new checklist, pending until its create sheet closes.
///
/// `itemIDs` are the originals in the source, captured when the copies were made. The copies carry
/// new ids, so nothing done to them on the create sheet can change which originals a move removes.
struct CheckedItemsTransfer: Hashable {
  let sourceID: String
  let mode: CheckedItemsTransferMode
  let itemIDs: [String]
}
