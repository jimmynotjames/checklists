//
//  InMemoryKeyValueStore.swift
//  checklists
//

import Foundation

/// A disposable, per-process `KeyValueStore` that never touches disk. Test launches use it — see
/// `AnalyticsSettings.makeStore`.
final class InMemoryKeyValueStore: KeyValueStore {
  private var storage: [String: Any] = [:]

  func object(forKey key: String) -> Any? {
    storage[key]
  }

  func set(_ value: Bool, forKey defaultName: String) {
    storage[defaultName] = value
  }

  func set(_ value: Int, forKey defaultName: String) {
    storage[defaultName] = value
  }

  func set(_ value: String, forKey defaultName: String) {
    storage[defaultName] = value
  }

  func removeObject(forKey defaultName: String) {
    storage[defaultName] = nil
  }

  @discardableResult
  func synchronize() -> Bool {
    true
  }
}
