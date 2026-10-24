//
//  SavedHeadersStore.swift
//  checklists
//

import Foundation
import Observation

/// The Headers someone chose to keep for reuse in the export sheet, newest first.
///
/// On this device only, with no limit and no sync: every entry was saved on purpose, and the
/// Saved Headers menu's Delete is the way to remove one. Kept out of SwiftData, so `StoreReset`
/// leaves it alone, as it does the other device preferences.
@Observable
@MainActor
final class SavedHeadersStore {
  static let savedHeadersKey = "pdfSavedHeaders"

  private let store: KeyValueStore

  private(set) var headers: [String] {
    didSet {
      // JSON in a string, so `KeyValueStore` needs no array setter for one caller.
      guard let data = try? JSONEncoder().encode(headers), let json = String(data: data, encoding: .utf8) else { return }
      store.set(json, forKey: Self.savedHeadersKey)
      _ = store.synchronize()
    }
  }

  init(store: KeyValueStore = SavedHeadersStore.defaultStore()) {
    self.store = store
    headers = Self.read(from: store)
  }

  /// Whether Save for Reuse applies: there is something besides whitespace, and it is not already
  /// saved. A Saved Header with job details typed under it counts as new; that is trusted to the
  /// person.
  func canSave(_ text: String) -> Bool {
    let normalized = HeaderText.normalized(text)
    return !normalized.isEmpty && !headers.contains(normalized)
  }

  func save(_ text: String) {
    guard canSave(text) else { return }
    headers.insert(HeaderText.normalized(text), at: 0)
  }

  func delete(_ header: String) {
    headers.removeAll { $0 == header }
  }

  /// Test-launch isolation as in `AnalyticsSettings.makeStore`.
  static func defaultStore() -> KeyValueStore {
    LaunchModeContainerFactory.isRunningTests ? InMemoryKeyValueStore() : UserDefaults.standard
  }

  /// Unreadable data reads as nothing saved rather than failing the sheet.
  private static func read(from store: KeyValueStore) -> [String] {
    guard let json = store.object(forKey: savedHeadersKey) as? String,
          let headers = try? JSONDecoder().decode([String].self, from: Data(json.utf8)) else { return [] }
    return headers
  }
}
