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
/// Each test observes and posts on a `NotificationCenter` of its own. On `.default`, a remote-change
/// or `didRemoveDuplicates` post from anywhere else in the process restarts the debounce or adds a
/// callback the test didn't cause. `.serialized` keeps these timing-bound tests from competing with
/// each other for the main actor.
@Suite("RemoteChangeObserver coalescing", .serialized)
struct RemoteChangeObserverTests {
  /// `confirmation` is doing two jobs: it fails if the callback never arrives, and it fails if it
  /// arrives more than once. Coalescing is only proven by the second half.
  ///
  /// Hence the sleep, at ten times the coalescing delay — it has to outlast any second, un-coalesced
  /// callback rather than return the moment the first one lands. `Task.sleep` also yields the main
  /// actor, which the observer's callback needs in order to run at all.
  @Test("a burst of remote-change notifications collapses into one callback", .timeLimit(.minutes(1)))
  func postingNotificationCallsOnChangeOnce() async throws {
    let center = NotificationCenter()
    try await confirmation("coalesced callback fired") { callbackFired in
      // Held for the duration of the test: `RemoteChangeObserver` unregisters its notification
      // observer on deallocation, so an observer that goes out of scope early would silently stop
      // seeing the notifications posted below.
      let observer = RemoteChangeObserver(coalescingDelay: .milliseconds(50), notificationCenter: center) {
        callbackFired()
      }

      for _ in 0 ..< 3 {
        center.post(name: .NSPersistentStoreRemoteChange, object: nil)
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
  /// into one reschedule and the deadline would never engage.
  ///
  /// The elapsed-time bound is what stops the test passing for the wrong reason. On a loaded
  /// machine the 20ms gaps can stretch past the debounce, at which point the burst goes quiet and
  /// a debounce-only implementation would also fire — but only after the whole loop, so the first
  /// callback arriving well before then is reachable by the deadline alone.
  @Test("a burst that never goes quiet still fires on the deadline", .timeLimit(.minutes(1)))
  func sustainedBurstFiresOnMaximumDelay() async throws {
    let started = ContinuousClock.now
    var firstFiredAt: ContinuousClock.Instant?

    let center = NotificationCenter()
    try await confirmation("deadline callback fired", expectedCount: 1...) { callbackFired in
      let observer = RemoteChangeObserver(
        coalescingDelay: .milliseconds(50),
        maximumDelay: .milliseconds(120),
        notificationCenter: center,
      ) {
        firstFiredAt = firstFiredAt ?? ContinuousClock.now
        callbackFired()
      }

      for _ in 0 ..< 20 {
        center.post(name: .NSPersistentStoreRemoteChange, object: nil)
        try await Task.sleep(for: .milliseconds(20))
      }

      withExtendedLifetime(observer) {}
    }

    let elapsed = try started.duration(to: #require(firstFiredAt))
    #expect(elapsed < .milliseconds(300))
  }

  /// Guards against the two bounds being swapped, which would turn every notification into an
  /// immediate callback.
  @Test("a single notification waits out the debounce", .timeLimit(.minutes(1)))
  func quietBurstWaitsForCoalescingDelay() async throws {
    let started = ContinuousClock.now
    var firedAt: ContinuousClock.Instant?

    let center = NotificationCenter()
    try await confirmation("debounced callback fired") { callbackFired in
      let observer = RemoteChangeObserver(
        coalescingDelay: .milliseconds(100),
        maximumDelay: .seconds(5),
        notificationCenter: center,
      ) {
        firedAt = ContinuousClock.now
        callbackFired()
      }

      center.post(name: .NSPersistentStoreRemoteChange, object: nil)
      try await Task.sleep(for: .milliseconds(400))

      withExtendedLifetime(observer) {}
    }

    let elapsed = try started.duration(to: #require(firedAt))
    #expect(elapsed >= .milliseconds(90))
  }

  /// Without the reset, `burstStart` would latch at the first notification and every later
  /// reschedule would clamp to an already-elapsed deadline, throttling the callback forever
  /// instead of returning to the trailing debounce once the burst ends.
  ///
  /// As above, the elapsed-time bound on the first callback is what keeps this from passing on a
  /// debounce-only implementation when a loaded machine stretches the gaps.
  @Test("a burst still gets a trailing callback after a deadline fire", .timeLimit(.minutes(1)))
  func burstResumesDebouncingAfterDeadlineFire() async throws {
    let started = ContinuousClock.now
    var firstFiredAt: ContinuousClock.Instant?

    let center = NotificationCenter()
    try await confirmation("deadline and trailing callbacks fired", expectedCount: 2...) { callbackFired in
      let observer = RemoteChangeObserver(
        coalescingDelay: .milliseconds(50),
        maximumDelay: .milliseconds(100),
        notificationCenter: center,
      ) {
        firstFiredAt = firstFiredAt ?? ContinuousClock.now
        callbackFired()
      }

      // Long enough to cross the deadline at least once.
      for _ in 0 ..< 10 {
        center.post(name: .NSPersistentStoreRemoteChange, object: nil)
        try await Task.sleep(for: .milliseconds(20))
      }
      // Then go quiet, so the trailing debounce delivers a second callback.
      try await Task.sleep(for: .milliseconds(300))

      withExtendedLifetime(observer) {}
    }

    let elapsed = try started.duration(to: #require(firstFiredAt))
    #expect(elapsed < .milliseconds(200))
  }
}
