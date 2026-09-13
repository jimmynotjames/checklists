//
//  TestScope.swift
//  checklistsTests
//

import Foundation

/// Scoped replacements for the `setUp`/`tearDown` pairs the suites used while they were
/// `XCTestCase` subclasses.
///
/// A Swift Testing suite is a `struct`, which has no `deinit` to tear down in, so per-test
/// fixtures are handed to the test through a closure and cleaned up in `defer`. That is the
/// better shape regardless of framework: creation and cleanup sit next to each other instead of
/// forty lines apart, and nothing has to be stored in an implicitly-unwrapped `var` that crashes
/// rather than fails when setup is skipped. Ported from the same pattern in `budgets1`'s
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
  /// simulator's real app container, and into `make test-ui`.
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
