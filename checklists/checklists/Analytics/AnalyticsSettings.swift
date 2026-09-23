//
//  AnalyticsSettings.swift
//  checklists
//

import Foundation
import Observation

/// The always-on Settings toggle and first-run consent state (core-docs/analytics-spec.md
/// §Identity, §Consent).
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

  var analyticsOptIn: Bool {
    didSet {
      store.set(analyticsOptIn, forKey: Self.analyticsOptInKey)
      _ = store.synchronize()
    }
  }

  /// `true` iff the backing store contains an explicit value for `"analyticsOptIn"`.
  var analyticsOptInExplicitlySet: Bool {
    store.object(forKey: Self.analyticsOptInKey) != nil
  }

  /// A stable UUIDv4 string used as the Mixpanel `distinct_id`. Generated once and persisted;
  /// `MixpanelAnalyticsClient.reset()` clears the SDK's notion of it but not this value, so a
  /// re-opt-in rejoins the same Mixpanel profile — why this lives here rather than in the client.
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

  private static func defaultStore() -> KeyValueStore {
    makeStore(
      arguments: CommandLine.arguments,
      environment: ProcessInfo.processInfo.environment,
      persistentStore: UserDefaults.standard
    )
  }

  /// Builds the settings store for a launch. Under `LaunchModeContainerFactory.isRunningTests`
  /// every launch gets a fresh `InMemoryKeyValueStore` — the same test-launch isolation as the
  /// in-memory `ModelContainer` — so a UI test's consent decision cannot leak into the next
  /// launch. `RatingPromptState` applies the same rule. Screenshot launches additionally begin
  /// with an explicit opt-out so a strict-region consent sheet cannot cover a marketing capture.
  static func makeStore(
    arguments: [String],
    environment: [String: String],
    persistentStore: @autoclosure () -> KeyValueStore
  ) -> KeyValueStore {
    guard LaunchModeContainerFactory.isRunningTests(arguments: arguments, environment: environment) else {
      return persistentStore()
    }

    let store = InMemoryKeyValueStore()
    #if DEBUG
      if environment[LaunchModeContainerFactory.screenshotSeedJSONKey] != nil,
         let locale = environment[LaunchModeContainerFactory.screenshotSeedLocaleKey],
         !locale.isEmpty {
        store.set(false, forKey: analyticsOptInKey)
      }
    #endif
    return store
  }

  private static func readAnalyticsOptIn(from store: KeyValueStore) -> Bool {
    guard let object = store.object(forKey: analyticsOptInKey) else {
      return ConsentJurisdiction.kind(for: Locale.current.region?.identifier) == .autoOptin
    }
    if let value = object as? Bool { return value }
    if let number = object as? NSNumber { return number.boolValue }
    return ConsentJurisdiction.kind(for: Locale.current.region?.identifier) == .autoOptin
  }

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
