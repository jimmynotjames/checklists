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

  /// Backgrounding *through* `.inactive` is the real-world path, and the phase immediately before
  /// `.active` is `.inactive` in that sequence too — so the tracker must not fire. The open is
  /// already counted by the launch, and iOS delivers `.inactive` on the way back in.
  @MainActor func testBackgroundThenInactiveThenActiveDoesNotDoubleFire() {
    let tracker = AppOpenTracker()
    _ = tracker.shouldFire(for: .active)
    _ = tracker.shouldFire(for: .inactive)
    _ = tracker.shouldFire(for: .background)
    XCTAssertTrue(tracker.shouldFire(for: .active), "background → active is an open.")
    XCTAssertFalse(tracker.shouldFire(for: .active), "Staying active is not a second open.")
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
