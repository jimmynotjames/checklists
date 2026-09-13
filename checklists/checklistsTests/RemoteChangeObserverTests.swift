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
  /// `confirmation` is doing two jobs: it fails if the callback never arrives, and it fails if it
  /// arrives more than once. Coalescing is only proven by the second half.
  ///
  /// Hence the sleep, at ten times the coalescing delay — it has to outlast any second, un-coalesced
  /// callback rather than return the moment the first one lands. `Task.sleep` also yields the main
  /// actor, which the observer's callback needs in order to run at all.
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
