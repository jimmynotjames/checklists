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
/// **The rule is "has `.background` been seen since the last open", not "was the previous phase
/// `.background`".** iOS delivers `.inactive` on the way back in, so a real foreground return
/// arrives as `background → inactive → active`; testing only the immediately preceding phase
/// misses every one of them and reduces the event to cold launches. Verified on device by
/// backgrounding and reopening.
///
/// No session-length constant here on purpose — sessionization is the backend's job, not
/// something the client should half-reimplement.
@MainActor
final class AppOpenTracker {
  private var hasFired = false
  private var sawBackgroundSinceLastOpen = false

  /// Records `phase` and reports whether it should fire `app_opened`: true on the first observed
  /// `.active` (cold launch) and on the first `.active` after any `.background`; false for
  /// `.inactive` flicker and for non-active phases.
  func shouldFire(for phase: ScenePhase) -> Bool {
    switch phase {
    case .background:
      sawBackgroundSinceLastOpen = true
      return false
    case .active:
      guard !hasFired || sawBackgroundSinceLastOpen else { return false }
      hasFired = true
      sawBackgroundSinceLastOpen = false
      return true
    default:
      // `.inactive`, and any phase a future SDK adds: not an open on its own, and deliberately
      // does not clear the background flag — that is the whole point of the rule above.
      return false
    }
  }
}
