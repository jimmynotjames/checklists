//
//  AppOpenTrackerTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftUI
import XCTest

/// Covers which `scenePhase` transitions count as an app open (analytics-spec.md §8).
///
/// The `.inactive` cases are the point of this class. A drop to `.inactive` and back happens for
/// the notification shade, the app switcher, Face ID and permission dialogs — none of which are
/// someone opening the app. Counting them would inflate every reach and retention number on the
/// dashboards, and the inflation would look like real growth.
///
/// See the note on `AnalyticsTextTests` for the `nonisolated` class / `@MainActor` method pattern.
nonisolated final class AppOpenTrackerTests: XCTestCase {
  @MainActor func testFirstActiveFires() {
    let tracker = AppOpenTracker()
    XCTAssertTrue(tracker.shouldFire(for: .active), "A cold launch is an open.")
  }

  @MainActor func testReturnFromBackgroundFires() {
    let tracker = AppOpenTracker()
    _ = tracker.shouldFire(for: .active)
    _ = tracker.shouldFire(for: .background)
    XCTAssertTrue(tracker.shouldFire(for: .active), "Returning from background is an open.")
  }

  @MainActor func testInactiveFlickerDoesNotFire() {
    let tracker = AppOpenTracker()
    _ = tracker.shouldFire(for: .active)
    _ = tracker.shouldFire(for: .inactive)
    XCTAssertFalse(
      tracker.shouldFire(for: .active),
      "The notification shade and app switcher are not app opens."
    )
  }

  /// **The sequence iOS actually delivers**, measured on a device: backgrounding goes
  /// `active → inactive → background`, and reopening comes back `inactive → active`. So the phase
  /// immediately before the `.active` that ends a real foreground return is `.inactive`, never
  /// `.background`.
  ///
  /// This is the case that matters most. A rule that inspects only the phase immediately before
  /// `.active` sees `.inactive` here and stays silent, which reduces `app_opened` to cold launches
  /// and puts every session, reach and retention number on that footing. Keep this test pointed at
  /// the full sequence, not at a single transition.
  @MainActor func testRealForegroundReturnSequenceFires() {
    let tracker = AppOpenTracker()
    XCTAssertTrue(tracker.shouldFire(for: .active), "Cold launch.")
    _ = tracker.shouldFire(for: .inactive)
    _ = tracker.shouldFire(for: .background)
    XCTAssertFalse(tracker.shouldFire(for: .inactive), "Still on the way back in.")
    XCTAssertTrue(tracker.shouldFire(for: .active), "This is the foreground return.")
  }

  /// Two full cycles, to prove the background flag is cleared on each open rather than latching
  /// true and firing on every subsequent `.active`.
  @MainActor func testTwoForegroundReturnsFireTwiceNotMore() {
    let tracker = AppOpenTracker()
    var opens = 0
    for phase in [ScenePhase.active, .inactive, .background, .inactive, .active,
                  .inactive, .background, .inactive, .active] where tracker.shouldFire(for: phase) {
      opens += 1
    }
    XCTAssertEqual(opens, 3, "One cold launch plus two foreground returns.")
  }

  /// The flicker case, stated against the same rule: an `.inactive` detour with no `.background`
  /// in it is the notification shade or the app switcher, and is not an open.
  @MainActor func testInactiveDetourWithoutBackgroundDoesNotFire() {
    let tracker = AppOpenTracker()
    _ = tracker.shouldFire(for: .active)
    _ = tracker.shouldFire(for: .inactive)
    XCTAssertFalse(tracker.shouldFire(for: .active))
    XCTAssertFalse(tracker.shouldFire(for: .active), "Staying active is not a second open.")
  }

  /// A scene that connects in the background — possible here because the app declares the
  /// remote-notification background mode — must not count as an open, and must not swallow the
  /// person's real open when they later launch it.
  @MainActor func testBackgroundLaunchDoesNotFireButLaterActivationDoes() {
    let tracker = AppOpenTracker()
    XCTAssertFalse(tracker.shouldFire(for: .background), "A background launch is not an open.")
    XCTAssertTrue(tracker.shouldFire(for: .active), "Opening it afterwards is.")
  }

  @MainActor func testRepeatedActiveDoesNotFireTwice() {
    let tracker = AppOpenTracker()
    XCTAssertTrue(tracker.shouldFire(for: .active))
    XCTAssertFalse(tracker.shouldFire(for: .active))
  }

  @MainActor func testNonActivePhasesNeverFire() {
    let tracker = AppOpenTracker()
    XCTAssertFalse(tracker.shouldFire(for: .background))
    XCTAssertFalse(tracker.shouldFire(for: .inactive))
  }
}
