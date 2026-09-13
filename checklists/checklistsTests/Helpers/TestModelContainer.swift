//
//  TestModelContainer.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData

/// An isolated, disposable SwiftData stack for unit tests.
///
/// In memory, so nothing survives a test and nothing touches the simulator's real store — a
/// deliberate break from the old `DataModelTests`, which asserted against the *persisted* Realm
/// file and had to wipe it in `setUp`. CloudKit is off: a test must never reach the network, and a
/// CloudKit-backed configuration would also reject the schema for reasons that have nothing to do
/// with the test.
///
/// The real migration plan is passed in so that every test exercises the same container
/// construction the app uses.
enum TestModelContainer {
  static func make() throws -> ModelContainer {
    let configuration = ModelConfiguration(
      schema: SchemaV1.swiftDataSchema,
      isStoredInMemoryOnly: true,
      cloudKitDatabase: .none
    )
    return try ModelContainer(
      for: SchemaV1.swiftDataSchema,
      migrationPlan: ChecklistsMigrationPlan.self,
      configurations: configuration
    )
  }

  /// A fresh context over a fresh in-memory container — what most suites actually want.
  static func makeContext() throws -> ModelContext {
    try ModelContext(make())
  }
}
