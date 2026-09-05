//
//  ChecklistsMigrationPlan.swift
//  checklists
//

import Foundation
import SwiftData

/**
 Empty by design: `SchemaV1` is the first SwiftData schema, so there is nothing to migrate
 *from* within SwiftData. (The one-time copy out of the old Realm store is a separate concern —
 see `LegacyRealmImporter` — because it moves data between two different persistence stacks,
 which `SchemaMigrationPlan` cannot express.)

 The plan exists from day one anyway, wired into every `ModelContainer`, so that the first real
 schema change is a matter of adding a `SchemaV2` and a stage here rather than retrofitting the
 whole mechanism under pressure.
 */
enum ChecklistsMigrationPlan: SchemaMigrationPlan {
  static let schemas: [any VersionedSchema.Type] = [SchemaV1.self]

  static let stages: [MigrationStage] = []
}
