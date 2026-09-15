//
//  RatingPromptState.swift
//  checklists
//

import Foundation

/// Persisted eligibility signals for the automatic App Store review prompt.
///
/// Ported from `simple-recurring-budgets`'s `RatingPromptState`, with one deviation: it is backed
/// by `UserDefaults.standard` rather than the iCloud key-value store, because this app has no
/// `ubiquity-kvstore-identifier` entitlement (core-docs/analytics-spec.md §5, §16). The counters
/// are therefore per device, which only means a second device waits its own seven days.
///
/// **Independent of analytics consent.** These signals decide whether to ask for a review and must
/// work identically for someone who declined analytics, so nothing here reads or writes
/// `AnalyticsSettings`' keys. They ride on the same `KeyValueStore` seam only so the tests can hand
/// in an in-memory store.
///
/// Dates are stored as their `timeIntervalSinceReferenceDate` rendered to a string and counts as
/// `Int`, mirroring the sibling's convention so a reader of either repo's defaults sees the same
/// shape.
final class RatingPromptState {
  static let installedAtKey = "ratingPromptInstalledAt"
  static let checkedItemCountKey = "ratingPromptCheckedItemCount"
  static let distinctCheckDayCountKey = "ratingPromptDistinctCheckDayCount"
  static let lastCheckDayStartKey = "ratingPromptLastCheckDayStart"
  static let firstEligibleAtKey = "ratingPromptFirstEligibleAt"
  static let lastRequestedVersionKey = "ratingPromptLastRequestedVersion"

  private let store: KeyValueStore

  /// First-launch timestamp. Stamped once on the first init over a fresh store; never updated.
  ///
  /// On an install that predates this feature it is the first launch *after* the upgrade, so an
  /// existing user waits the same seven days a new one does. Deliberate: there is no older
  /// signal to borrow that is not analytics-gated.
  let installedAt: Date

  init(store: KeyValueStore = RatingPromptState.defaultStore()) {
    self.store = store
    installedAt = Self.readOrCreateInstalledAt(from: store)
  }

  /// Lifetime count of items checked off (checks only — unchecking is not a qualifying action).
  var checkedItemCount: Int {
    get { Self.readInt(store, Self.checkedItemCountKey) }
    set {
      store.set(newValue, forKey: Self.checkedItemCountKey)
      _ = store.synchronize()
    }
  }

  /// Number of distinct calendar days on which at least one item was checked off.
  var distinctCheckDayCount: Int {
    get { Self.readInt(store, Self.distinctCheckDayCountKey) }
    set {
      store.set(newValue, forKey: Self.distinctCheckDayCountKey)
      _ = store.synchronize()
    }
  }

  /// Start-of-day of the most recent check-off, used to detect a new distinct day.
  var lastCheckDayStart: Date? {
    get { Self.readDate(store, Self.lastCheckDayStartKey) }
    set { Self.writeDate(store, Self.lastCheckDayStartKey, newValue) }
  }

  /// When the thresholds were first met. The one-shot gate for `rating_prompt_eligible`.
  var firstEligibleAt: Date? {
    get { Self.readDate(store, Self.firstEligibleAtKey) }
    set { Self.writeDate(store, Self.firstEligibleAtKey, newValue) }
  }

  /// The app version (`CFBundleShortVersionString`) a review was last requested for. The local
  /// once-per-version guard; Apple's own throttle sits on top of it.
  var lastRequestedVersion: String? {
    get { store.object(forKey: Self.lastRequestedVersionKey) as? String }
    set {
      if let newValue {
        store.set(newValue, forKey: Self.lastRequestedVersionKey)
      } else {
        store.removeObject(forKey: Self.lastRequestedVersionKey)
      }
      _ = store.synchronize()
    }
  }

  // MARK: - Store selection

  /// The same test-launch isolation `AnalyticsSettings` applies to its own store: an automated
  /// launch gets a fresh in-memory store, so a UI test can never inherit — or leave behind —
  /// counters in the simulator's real defaults. Production uses `UserDefaults.standard`.
  static func defaultStore() -> KeyValueStore {
    LaunchModeContainerFactory.isRunningTests ? InMemoryKeyValueStore() : UserDefaults.standard
  }

  // MARK: - Private helpers

  private static func readInt(_ store: KeyValueStore, _ key: String) -> Int {
    switch store.object(forKey: key) {
    case let value as Int: value
    case let value as NSNumber: value.intValue
    default: 0
    }
  }

  private static func readDate(_ store: KeyValueStore, _ key: String) -> Date? {
    guard let raw = store.object(forKey: key) as? String, let interval = TimeInterval(raw) else {
      return nil
    }
    return Date(timeIntervalSinceReferenceDate: interval)
  }

  private static func writeDate(_ store: KeyValueStore, _ key: String, _ date: Date?) {
    if let date {
      store.set(date.timeIntervalSinceReferenceDate.description, forKey: key)
    } else {
      store.removeObject(forKey: key)
    }
    _ = store.synchronize()
  }

  private static func readOrCreateInstalledAt(from store: KeyValueStore) -> Date {
    if let existing = readDate(store, installedAtKey) {
      return existing
    }
    let now = Date()
    store.set(now.timeIntervalSinceReferenceDate.description, forKey: installedAtKey)
    _ = store.synchronize()
    return now
  }
}
