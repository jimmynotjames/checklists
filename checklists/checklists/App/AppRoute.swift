//
//  AppRoute.swift
//  checklists
//

import Foundation

/// Destinations for push navigation within the main `NavigationStack`.
///
/// Routes carry the model's stable `id` (`Checklist.id`), never a live model reference. The
/// destination view resolves the id at presentation time via `ModelContext.checklist(id:)` and
/// silently no-ops when the model no longer exists (e.g., deleted on another device).
enum AppRoute: Hashable {
  /// Drill into a specific checklist's items.
  case checklist(id: String)
}
