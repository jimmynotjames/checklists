//
//  RemoteChangeObserver.swift
//  checklists
//

import CoreData
import Foundation

/**
 Calls back when the persistent store is changed through a persistent store coordinator other than
 the one this app writes through — in practice, a CloudKit merge landing records from another
 device.

 `NSPersistentStoreRemoteChange` is the right signal because it is about *who wrote*, not *what
 changed*. Observing the model objects instead (`withObservationTracking`) cannot tell our own edit
 from a merged one, so it would fire during an in-flight table view animation and fight it.

 Registration passes `object: nil`, so there is no filtering by coordinator or by store: every
 remote-change notification posted anywhere in the process arrives here, including from a container
 this observer's owner knows nothing about. Harmless for a screen that reloads from its own context,
 but it is not the narrow subscription the argument list suggests.

 Changes arrive in bursts — a merge writes many records in quick succession — so the callback is
 debounced: each notification restarts a `coalescingDelay` wait, and the callback runs once the
 burst goes quiet. `maximumDelay` bounds that wait. An initial CloudKit import, whose notifications
 arrive faster than the debounce window for seconds at a time, would otherwise restart the wait
 forever and never refresh the screen at all. The callback therefore runs at the earlier of "quiet
 for `coalescingDelay`" and "`maximumDelay` since this burst's first notification".

 The notification is delivered on whichever queue posted it, hence the deliberate hop.
 */
@MainActor
final class RemoteChangeObserver: NSObject {
  private let onChange: () -> Void
  private let coalescingDelay: Duration
  private let maximumDelay: Duration
  private var pendingCallback: Task<Void, Never>?
  /// When the current burst's first notification arrived, or `nil` between bursts.
  private var burstStart: ContinuousClock.Instant?

  /// - Parameters:
  ///   - maximumDelay: the longest the callback is held back once a burst has started. Setting it
  ///     below `coalescingDelay` turns the debounce into a fixed-interval throttle.
  ///   - onChange: invoked on the main actor. Capture the owner weakly: the owner is expected to
  ///     hold this observer, so a strong capture would be a cycle.
  init(
    coalescingDelay: Duration = .milliseconds(200),
    maximumDelay: Duration = .seconds(1),
    onChange: @escaping () -> Void
  ) {
    self.onChange = onChange
    self.coalescingDelay = coalescingDelay
    self.maximumDelay = maximumDelay
    super.init()
    // The selector-based registration is unregistered automatically when this object is
    // deallocated, which the block-based API would not do.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(storeChangedRemotely),
      name: .NSPersistentStoreRemoteChange,
      object: nil
    )
  }

  /// `nonisolated` because the notification is delivered on whichever queue posted it.
  @objc nonisolated private func storeChangedRemotely() {
    Task { @MainActor [weak self] in
      self?.scheduleCallback()
    }
  }

  private func scheduleCallback() {
    let now = ContinuousClock.now
    let start = burstStart ?? now
    burstStart = start
    // An absolute deadline rather than a countdown: rescheduling recomputes when to fire, so a
    // burst that never goes quiet still cannot push the burst's own deadline further out.
    let fireAt = min(now.advanced(by: coalescingDelay), start.advanced(by: maximumDelay))
    pendingCallback?.cancel()
    pendingCallback = Task { @MainActor [weak self] in
      try? await Task.sleep(until: fireAt, clock: .continuous)
      guard !Task.isCancelled, let self else { return }
      // Clearing the start opens a fresh window, so a sustained import fires once per
      // `maximumDelay` and an ordinary burst still gets the full trailing wait.
      burstStart = nil
      pendingCallback = nil
      onChange()
    }
  }
}
