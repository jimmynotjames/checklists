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
/// `AppRoute` for the rationale on carrying stable ids rather than live model references.
enum SheetRoute: Hashable, Identifiable {
  case settings
  case newChecklist(id: String)
  case analyticsConsent
  /// The destination picker for "Copy Checked Items to…" and "Move Checked Items to…", carrying
  /// the id of the checklist the items are leaving.
  case transferCheckedItems(sourceID: String, mode: CheckedItemsTransferMode)

  var id: Self {
    self
  }
}

/// Whether the checked-items picker leaves the originals where they were.
enum CheckedItemsTransferMode: Hashable {
  case copy
  case move
}
