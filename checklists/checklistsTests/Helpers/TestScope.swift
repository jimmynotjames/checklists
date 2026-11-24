//
//  TestScope.swift
//  checklistsTests
//

import Foundation

/// Per-test fixtures that clean themselves up.
///
/// A suite is a `struct` with no `deinit`, so a fixture needing teardown is handed to the test
/// through a closure and released in `defer`. Creation and cleanup end up next to each other, and
/// nothing is stored in an implicitly-unwrapped `var` that would crash rather than fail if it were
/// never populated. Same pattern as `simple-recurring-budgets`'s
/// `MigrationTestSupport.withTemporaryStoreURL`.
enum TestScope {
  /// Runs `body` with a fresh, empty directory under the test process's temporary directory, and
  /// removes it — along with any SwiftData `-wal`/`-shm` siblings written into it — afterwards.
  static func withTemporaryDirectory<T>(_ label: String, _ body: (URL) throws -> T) throws -> T {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(label)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    return try body(directory)
  }

  /// Runs `body` with a `UserDefaults` on a suite name unique to this call, and removes the
  /// persistent domain afterwards.
  ///
  /// `.standard` is never touched: a test that wrote there would leak into the next test, into the
  /// simulator's real app container, and into `make ui-tests`.
  static func withIsolatedDefaults<T>(_ label: String, _ body: (UserDefaults) throws -> T) throws -> T {
    let suiteName = "\(label)-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      throw TestScopeError.couldNotOpenDefaults(suiteName)
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }
    return try body(defaults)
  }
}

enum TestScopeError: Error {
  case couldNotOpenDefaults(String)
}
