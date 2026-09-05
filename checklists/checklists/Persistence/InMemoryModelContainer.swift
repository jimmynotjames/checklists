//
//  InMemoryModelContainer.swift
//  checklists
//

import Foundation
import SwiftData

/// Throwaway containers that never touch disk or CloudKit. Used by UI tests, and by unit tests
/// through the test target's own helper.
enum InMemoryModelContainer {
  static func makeEmpty() throws -> ModelContainer {
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

  /// Empty container pre-populated with the first-launch fixture, which is also the contract the
  /// UI tests assert against.
  static func makeSeeded() throws -> ModelContainer {
    let container = try makeEmpty()
    try SampleData.seed(into: container.mainContext)
    return container
  }
}
