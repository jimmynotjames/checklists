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
/// Add a case here for each screen that is presented as a sheet.
enum SheetRoute: Hashable, Identifiable {
  case settings
  case newChecklist(id: String)

  var id: Self {
    self
  }
}
