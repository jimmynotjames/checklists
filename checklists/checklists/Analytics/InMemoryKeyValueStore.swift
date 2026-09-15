//
//  InMemoryKeyValueStore.swift
//  checklists
//

import Foundation

/// A disposable, per-process `KeyValueStore` that never touches disk.
///
/// Mirrors `InMemoryModelContainer`: `AnalyticsSettings` resolves to one of these instead of
/// `UserDefaults.standard` whenever `LaunchModeContainerFactory.isRunningTests`, exactly as
/// `LaunchModeContainerFactory.make()` resolves to an in-memory `ModelContainer` under the same
/// condition. This is test-launch isolation, matching the existing container behaviour — without
/// it, a UI test's consent decision would persist in the real `UserDefaults.standard` and leak
/// into every later launch, on the simulator and in later test runs alike.
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
