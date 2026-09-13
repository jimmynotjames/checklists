//
//  RemoteChangeObserverTests.swift
//  checklistsTests
//

@testable import checklists
import CoreData
import Testing

/// Covers `RemoteChangeObserver`'s coalescing: a burst of `NSPersistentStoreRemoteChange`
/// notifications — the shape a CloudKit merge actually produces — collapses into one callback.
@Suite("RemoteChangeObserver coalescing")
struct RemoteChangeObserverTests {
  /// `confirmation` replaces the XCTest expectation *and* the separate `callCount` assertion: it
  /// fails both when the callback never arrives and when it arrives twice.
  ///
  /// The sleep is ten times the coalescing delay, and it is what gives a *second*, un-coalesced
  /// callback time to show up and be caught. The XCTest version could not check that — `wait(for:)`
  /// returned on the first fulfilment and asserted the count immediately after, so a late second
  /// callback would have gone unnoticed. `Task.sleep` also yields the main actor, which the
  /// observer's callback needs in order to run at all.
  @Test("a burst of remote-change notifications collapses into one callback", .timeLimit(.minutes(1)))
  func postingNotificationCallsOnChangeOnce() async throws {
    try await confirmation("coalesced callback fired") { callbackFired in
      // Held for the duration of the test: `RemoteChangeObserver` unregisters its notification
      // observer on deallocation, so an observer that goes out of scope early would silently stop
      // seeing the notifications posted below.
      let observer = RemoteChangeObserver(coalescingDelay: .milliseconds(50)) {
        callbackFired()
      }

      for _ in 0 ..< 3 {
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
      }

      try await Task.sleep(for: .milliseconds(500))

      withExtendedLifetime(observer) {}
    }
  }
}
