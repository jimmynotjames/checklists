//
//  RemoteChangeObserverTests.swift
//  checklistsTests
//

@testable import checklists
import CoreData
import Testing

/// Covers `RemoteChangeObserver`'s debounce: a burst of `NSPersistentStoreRemoteChange`
/// notifications — the shape a CloudKit merge actually produces — collapses into one callback, and
/// a burst that never goes quiet still fires on the maximum-delay deadline.
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

  /// The starvation case the maximum delay exists for: notifications arriving faster than the
  /// debounce window, which is what an initial CloudKit import on a device joining an existing
  /// account looks like. Without the deadline this fires zero times.
  ///
  /// The `await` between posts is load-bearing. This suite is main-actor isolated, so posting
  /// without suspending queues every hop to land at the same instant — the burst would collapse
  /// into one reschedule and the deadline would never engage. Keep the gap under the debounce or
  /// the burst goes quiet and proves nothing.
  @Test("a burst that never goes quiet still fires on the deadline", .timeLimit(.minutes(1)))
  func sustainedBurstFiresOnMaximumDelay() async throws {
    try await confirmation("deadline callback fired", expectedCount: 1...) { callbackFired in
      let observer = RemoteChangeObserver(
        coalescingDelay: .milliseconds(50),
        maximumDelay: .milliseconds(120)
      ) {
        callbackFired()
      }

      for _ in 0 ..< 20 {
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
        try await Task.sleep(for: .milliseconds(20))
      }

      withExtendedLifetime(observer) {}
    }
  }

  /// The deadline must not pre-empt the ordinary path: one notification still waits out the full
  /// debounce rather than firing immediately. Guards against the two bounds being swapped.
  @Test("a single notification waits out the debounce", .timeLimit(.minutes(1)))
  func quietBurstWaitsForCoalescingDelay() async throws {
    let started = ContinuousClock.now
    var firedAt: ContinuousClock.Instant?

    try await confirmation("debounced callback fired") { callbackFired in
      let observer = RemoteChangeObserver(
        coalescingDelay: .milliseconds(100),
        maximumDelay: .seconds(5)
      ) {
        firedAt = ContinuousClock.now
        callbackFired()
      }

      NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
      try await Task.sleep(for: .milliseconds(400))

      withExtendedLifetime(observer) {}
    }

    let elapsed = try started.duration(to: #require(firedAt))
    #expect(elapsed >= .milliseconds(90))
  }

  /// A deadline fire opens a fresh window rather than latching it, so the burst that follows is
  /// debounced normally instead of being throttled forever.
  @Test("a burst still gets a trailing callback after a deadline fire", .timeLimit(.minutes(1)))
  func burstResumesDebouncingAfterDeadlineFire() async throws {
    try await confirmation("deadline and trailing callbacks fired", expectedCount: 2...) { callbackFired in
      let observer = RemoteChangeObserver(
        coalescingDelay: .milliseconds(50),
        maximumDelay: .milliseconds(100)
      ) {
        callbackFired()
      }

      // Long enough to cross the deadline at least once.
      for _ in 0 ..< 10 {
        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
        try await Task.sleep(for: .milliseconds(20))
      }
      // Then go quiet, so the trailing debounce delivers a second callback.
      try await Task.sleep(for: .milliseconds(300))

      withExtendedLifetime(observer) {}
    }
  }
}
