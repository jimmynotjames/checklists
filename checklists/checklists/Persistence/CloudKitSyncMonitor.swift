//
//  CloudKitSyncMonitor.swift
//  checklists
//

import CloudKit
import CoreData
import Foundation

/// Observes `NSPersistentCloudKitContainer.eventChangedNotification` and folds each finished event
/// into `SyncStatus.syncActivity`. Owned by `PersistenceController`, started only on a CloudKit-backed
/// launch. Device check greps its `.info` log line: persistence-design.md §Sync status.
@MainActor
final class CloudKitSyncMonitor {
  private let syncStatus: SyncStatus
  private let analytics: any AnalyticsClient
  /// Written once in `init`, read once in `deinit` — both single-threaded moments in this object's
  /// lifecycle. `nonisolated(unsafe)` because `deinit` cannot be main-actor-isolated.
  nonisolated(unsafe) private var observer: NSObjectProtocol?
  /// Dedupes `cloudkit_sync_failed` to once per (operation, domain, code) for this launch.
  private var reportedFailures: Set<String> = []

  init(syncStatus: SyncStatus, analytics: any AnalyticsClient = AppAnalytics.shared) {
    self.syncStatus = syncStatus
    self.analytics = analytics
    // `object: nil`: SwiftData owns the underlying `NSPersistentCloudKitContainer`, so there is no
    // container instance here to filter on.
    observer = NotificationCenter.default.addObserver(
      forName: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil,
      queue: nil
    ) { [weak self] notification in
      guard let snapshot = SyncEventSnapshot(notification) else { return }
      // The notification arrives off the main actor; hop before touching `syncStatus`.
      Task { @MainActor [weak self] in
        self?.handle(snapshot)
      }
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  /// Internal rather than `private` so `CloudKitSyncMonitorTests` can drive the dedup-and-track
  /// logic directly with a constructed `SyncEventSnapshot` — the real `Event` this normally comes
  /// from can't be built in a test.
  func handle(_ snapshot: SyncEventSnapshot) {
    syncStatus.record(snapshot)
    AppLog.cloudKit.info(
      "cloudkit.sync.event: \(snapshot.operation.rawValue, privacy: .public) \(snapshot.error == nil, privacy: .public) \(snapshot.error?.domain ?? "-", privacy: .public) \(snapshot.error?.code ?? 0, privacy: .public)"
    )

    guard let error = snapshot.error else { return }
    let key = "\(snapshot.operation.rawValue)|\(error.domain)|\(error.code)"
    guard reportedFailures.insert(key).inserted else { return }
    analytics.track(
      AnalyticsEvent.cloudkitSyncFailed,
      properties: [
        AnalyticsProperty.syncOperation: snapshot.operation.rawValue,
        AnalyticsProperty.errorDomain: error.domain,
        AnalyticsProperty.errorCode: error.code,
      ]
    )
  }
}

extension SyncOperation {
  nonisolated init(_ eventType: NSPersistentCloudKitContainer.EventType) {
    switch eventType {
    case .setup: self = .setup
    case .import: self = .import
    case .export: self = .export
    // Only three event types are defined today; treated as `.import` rather than dropping the
    // event outright.
    @unknown default: self = .import
    }
  }
}

extension SyncEventSnapshot {
  /// `nil` for an event with no `endDate` yet (still in progress) or a malformed notification.
  /// `nonisolated`: parsed on whatever thread posts the notification, before the hop to the main
  /// actor in `CloudKitSyncMonitor.init`'s observer block.
  nonisolated init?(_ notification: Notification) {
    guard
      let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
      as? NSPersistentCloudKitContainer.Event,
      let endDate = event.endDate
    else { return nil }
    self.init(
      operation: SyncOperation(event.type),
      endDate: endDate,
      error: event.error.map(SyncErrorCode.init(unwrapping:))
    )
  }
}

extension SyncErrorCode {
  /// Unwraps `CKError.partialFailure` to its first underlying error; any other error is used as-is.
  /// Unit-tested directly with constructed `CKError`s — the real `Event` type can't be built in
  /// tests.
  nonisolated init(unwrapping error: Error) {
    if let ckError = error as? CKError,
       ckError.code == .partialFailure,
       let first = ckError.partialErrorsByItemID?.values.first {
      let inner = first as NSError
      self.init(domain: inner.domain, code: inner.code)
    } else {
      let nsError = error as NSError
      self.init(domain: nsError.domain, code: nsError.code)
    }
  }
}
