//
//  RemoteChangeObserver.swift
//  checklists
//

import CoreData
import Foundation

/**
 Calls back when the persistent store is changed by something other than this app's own context —
 in practice, a CloudKit merge landing records from another device.

 `NSPersistentStoreRemoteChange` is the right signal precisely because it fires only for *external*
 writes. Observing the model objects instead (`withObservationTracking`) cannot tell our own edit
 from a remote one, so it would fire during an in-flight table view animation and fight it.

 Changes arrive in bursts — a merge writes many records in quick succession — so callbacks are
 coalesced into one. The notification is posted on a background queue, hence the deliberate hop.

 Inert until CloudKit is switched on; wired up now so that both screens already refresh from a
 single, testable place when it is.
 */
@MainActor
final class RemoteChangeObserver: NSObject {
  private let onChange: () -> Void
  private let coalescingDelay: Duration
  private var pendingCallback: Task<Void, Never>?

  /// - Parameter onChange: invoked on the main actor. Capture the owner weakly: the owner is
  ///   expected to hold this observer, so a strong capture would be a cycle.
  init(coalescingDelay: Duration = .milliseconds(200), onChange: @escaping () -> Void) {
    self.onChange = onChange
    self.coalescingDelay = coalescingDelay
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
      self?.scheduleCoalescedCallback()
    }
  }

  private func scheduleCoalescedCallback() {
    pendingCallback?.cancel()
    pendingCallback = Task { @MainActor [weak self, coalescingDelay] in
      try? await Task.sleep(for: coalescingDelay)
      guard !Task.isCancelled, let self else { return }
      onChange()
    }
  }
}
