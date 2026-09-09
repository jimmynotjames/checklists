//
//  AppOpenTracker.swift
//  checklists
//

import SwiftUI

/// Decides whether a `scenePhase` transition should fire `app_opened`.
///
/// Mixpanel has no session concept of its own — it derives sessions server-side from this event
/// stream — so a foreground has to be reported explicitly. Flurry's `startSession` did this
/// invisibly, which is why the event is new (§14).
///
/// A cold launch and a return from background are both opens. A drop to `.inactive` and back is
/// not: the notification shade, the app switcher, Face ID and permission dialogs all produce that
/// transition, and counting them would inflate every reach and retention number.
///
/// No session-length constant here on purpose — sessionization is the backend's job, not
/// something the client should half-reimplement.
@MainActor
final class AppOpenTracker {
  private var lastPhase: ScenePhase?

  /// Records `phase` and reports whether it should fire `app_opened`: true on the first observed
  /// `.active` (cold launch) and on any `.background → .active` return; false for
  /// `.inactive → .active` flicker and for non-active phases.
  func shouldFire(for phase: ScenePhase) -> Bool {
    defer { lastPhase = phase }
    guard phase == .active else { return false }
    switch lastPhase {
    case .none, .some(.background):
      return true
    default:
      return false
    }
  }
}
