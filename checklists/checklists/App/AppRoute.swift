//
//  AppRoute.swift
//  checklists
//

import Foundation

/// Destinations for push navigation within the main `NavigationStack`.
///
/// Routes carry the model's stable `id` (`Checklist.id`, a `String` — not a UUID, see
/// `Checklist`), never a live model reference, so they stay serializable for deep links
/// and App Intents (`simple-recurring-budgets`'s `AppRoute` pattern). The destination view
/// resolves the id at presentation time via `ModelContext.checklist(id:)` and silently no-ops
/// when the model no longer exists (e.g., deleted on another device).
///
/// Add a case here for each screen that is reached by drilling down (not by sheet).
enum AppRoute: Hashable {
  /// Drill into a specific checklist's items.
  case checklist(id: String)
}
