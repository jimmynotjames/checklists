//
//  KeyValueStore.swift
//  checklists
//

import Foundation

/// Minimal key-value persistence seam used by `AnalyticsSettings`.
///
/// Exists so the backing store is a one-line swap at the call site: production uses
/// `UserDefaults.standard` (see the conformance below for why), and tests use an in-memory
/// double instead of touching real defaults.
protocol KeyValueStore: AnyObject {
  func object(forKey key: String) -> Any?
  func set(_ value: Bool, forKey defaultName: String)
  func set(_ value: String, forKey defaultName: String)
  @discardableResult
  func synchronize() -> Bool
}

/// The production conformance. `checklists.entitlements` declares CloudKit but not
/// `com.apple.developer.ubiquity-kvstore-identifier`, so `NSUbiquitousKeyValueStore` would not
/// sync here — see core-docs/analytics-spec.md §5. `UserDefaults` already implements every
/// requirement except the `String` overload of `set`.
extension UserDefaults: KeyValueStore {
  func set(_ value: String, forKey defaultName: String) {
    set(value as Any, forKey: defaultName)
  }
}

/// Unused today — `AnalyticsSettings` defaults to `UserDefaults.standard` — but kept so a later
/// migration to iCloud-synced consent state is a one-line change at the call site, once the
/// entitlement above is added.
extension NSUbiquitousKeyValueStore: KeyValueStore {
  func set(_ value: String, forKey defaultName: String) {
    set(value as Any, forKey: defaultName)
  }
}
