//
//  MockKeyValueStore.swift
//  checklistsTests
//

@testable import checklists
import Foundation

/// In-memory `KeyValueStore` for testing `AnalyticsSettings` without touching real
/// `UserDefaults`.
final class MockKeyValueStore: KeyValueStore {
  private var storage: [String: Any] = [:]

  func object(forKey key: String) -> Any? {
    storage[key]
  }

  func set(_ value: Bool, forKey defaultName: String) {
    storage[defaultName] = value
  }

  func set(_ value: String, forKey defaultName: String) {
    storage[defaultName] = value
  }

  @discardableResult
  func synchronize() -> Bool {
    true
  }
}
