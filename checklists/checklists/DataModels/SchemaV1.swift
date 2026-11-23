//
//  SchemaV1.swift
//  checklists
//

import Foundation
import SwiftData

/**
 The app's SwiftData schema, version 1 — the first schema to ship on SwiftData, replacing the
 Realm object graph that shipped through v1.1.0.

 **Frozen: the CloudKit production schema was deployed on 2026-11-23.** CloudKit schemas are
 additive only: once a record type or field reaches production it can never be removed or
 renamed. So a model change now means a *new* `VersionedSchema` plus a
 `MigrationStage` in `ChecklistsMigrationPlan` plus a migration test — never an edit in place.
 See persistence-design.md §CloudKit rules.
 */
enum SchemaV1: VersionedSchema {
  static let versionIdentifier = Schema.Version(1, 0, 0)

  static let models: [any PersistentModel.Type] = [
    Checklist.self,
    Item.self,
  ]

  /// The single source of truth for the model list, shared by the production container factory,
  /// the in-memory containers, and the tests.
  static var swiftDataSchema: Schema {
    Schema(versionedSchema: Self.self)
  }
}
