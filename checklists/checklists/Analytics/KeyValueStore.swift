//
//  KeyValueStore.swift
//  checklists
//

import Foundation

/// Minimal key-value persistence seam used by `AnalyticsSettings` and `RatingPromptState`.
///
/// Exists so the backing store is a one-line swap: production uses `UserDefaults.standard`, and
/// test launches and unit tests use `InMemoryKeyValueStore`.
protocol KeyValueStore: AnyObject {
  func object(forKey key: String) -> Any?
  func set(_ value: Bool, forKey defaultName: String)
  func set(_ value: Int, forKey defaultName: String)
  func set(_ value: String, forKey defaultName: String)
  func removeObject(forKey defaultName: String)
  @discardableResult
  func synchronize() -> Bool
}

/// The production conformance. `UserDefaults` already implements every requirement except the
/// `String` overload of `set`.
extension UserDefaults: KeyValueStore {
  func set(_ value: String, forKey defaultName: String) {
    set(value as Any, forKey: defaultName)
  }
}

/// Unused: without the `ubiquity-kvstore-identifier` entitlement it would not sync
/// (core-docs/analytics-spec.md §Identity). Its native integer setter takes `Int64`, hence the
/// `Int` bridge.
extension NSUbiquitousKeyValueStore: KeyValueStore {
  func set(_ value: Int, forKey defaultName: String) {
    set(Int64(value), forKey: defaultName)
  }

  func set(_ value: String, forKey defaultName: String) {
    set(value as Any, forKey: defaultName)
  }
}
