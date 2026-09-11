//
//  AnalyticsSettings.swift
//  checklists
//

import Foundation
import Observation

/// The always-on Settings toggle and first-run consent state (core-docs/analytics-spec.md §5,
/// §6).
///
/// **The opt-in default is locale-aware but never persisted.** `analyticsOptIn` resolves from
/// `ConsentJurisdiction` whenever the store holds no explicit value; writing that resolved
/// default would make every install look like it had already decided.
/// `analyticsOptInExplicitlySet` is exactly `store.object(forKey:) != nil`, and that is what
/// gates the first-run consent sheet.
@Observable
@MainActor
final class AnalyticsSettings {
  static let analyticsOptInKey = "analyticsOptIn"
  static let analyticsDistinctIdKey = "analyticsDistinctId"

  private let store: KeyValueStore

  /// Whether the user has opted in to product analytics (Mixpanel). See the type doc comment for
  /// the locale-aware default and its never-persisted resolution. `@Observable` change
  /// notifications emit on every write.
  var analyticsOptIn: Bool {
    didSet {
      store.set(analyticsOptIn, forKey: Self.analyticsOptInKey)
      _ = store.synchronize()
    }
  }

  /// `true` iff the backing store contains an explicit value for `"analyticsOptIn"`.
  ///
  /// Consumed by the first-run consent-sheet trigger: `false` means the user has never made a
  /// consent decision.
  var analyticsOptInExplicitlySet: Bool {
    store.object(forKey: Self.analyticsOptInKey) != nil
  }

  /// A stable UUIDv4 string used as the Mixpanel `distinct_id` (§5).
  ///
  /// On first init with a fresh store, a new UUID is generated, written to the backing store,
  /// and returned. Subsequent reads return the stored value. `private(set)` — this type never
  /// changes it on its own. `MixpanelAnalyticsClient.reset()` does clear the SDK's own notion of
  /// the current distinct id, but the next lazy init re-identifies with this same stored UUID, so
  /// an opt-out followed by a re-opt-in rejoins the same Mixpanel profile rather than starting a
  /// new one — that persistence is the point of keeping this value here rather than in the client.
  private(set) var analyticsDistinctId: String {
    didSet {
      store.set(analyticsDistinctId, forKey: Self.analyticsDistinctIdKey)
      _ = store.synchronize()
    }
  }

  init(store: KeyValueStore = AnalyticsSettings.defaultStore()) {
    self.store = store
    // Locale-aware default; absent from the store → NOT persisted. `didSet` does not fire on a
    // property's first assignment inside its own type's initializer, so this read-through never
    // triggers the write above.
    analyticsOptIn = Self.readAnalyticsOptIn(from: store)
    // Generates and persists a UUID if the store has no value yet.
    analyticsDistinctId = Self.readOrCreateDistinctId(from: store)
  }

  /// `UserDefaults.standard` persists across process launches, so a UI test's consent decision
  /// would otherwise leak into the next test's launch. Test-launch isolation, mirroring
  /// `LaunchModeContainerFactory.make()`'s in-memory `ModelContainer` under the same condition —
  /// not a workaround, the same seam this app already uses for persistence.
  private static func defaultStore() -> KeyValueStore {
    LaunchModeContainerFactory.isRunningTests ? InMemoryKeyValueStore() : UserDefaults.standard
  }

  // MARK: - Private: store reads

  /// Reads `analyticsOptIn` from the store, falling back to the locale-aware default if no
  /// value has been persisted. The default is **not** written to the store.
  private static func readAnalyticsOptIn(from store: KeyValueStore) -> Bool {
    guard let object = store.object(forKey: analyticsOptInKey) else {
      return ConsentJurisdiction.kind(for: Locale.current.region?.identifier) == .autoOptin
    }
    if let value = object as? Bool { return value }
    if let number = object as? NSNumber { return number.boolValue }
    return ConsentJurisdiction.kind(for: Locale.current.region?.identifier) == .autoOptin
  }

  /// Reads the stored `analyticsDistinctId`. If absent, generates a new UUIDv4, persists it
  /// immediately (so the same id is returned on subsequent reads), and returns it.
  private static func readOrCreateDistinctId(from store: KeyValueStore) -> String {
    if let existing = store.object(forKey: analyticsDistinctIdKey) as? String, !existing.isEmpty {
      return existing
    }
    let newId = UUID().uuidString
    store.set(newId, forKey: analyticsDistinctIdKey)
    _ = store.synchronize()
    return newId
  }
}
