//
//  LegacyRealmSchema.swift
//  checklists
//
//  Created by Jimmy Ho on 5/23/19.
//

import Foundation
import RealmSwift

// MARK: - The pre-SwiftData Realm object graph, kept only so the old store can be read once

//
// These three classes are the *exact* on-disk schema of App Store v1.1.0, the last Realm
// release. They exist for one purpose: `LegacyRealmImporter` opens the old `default.realm`
// with them, copies everything into SwiftData, and never touches Realm again. Nothing else in
// the app may use them.
//
// **Do not change these declarations.** Realm derives a table's name from the Objective-C
// runtime class name (`NSStringFromClass`, `RLMObjectSchema.mm`), which is why each class carries
// an `@objc(...)` attribute pinning it to the original name — the Swift-side rename to
// `Legacy*` exists only to free up `Checklist` and `Item` for the SwiftData models, and is
// invisible to the file on disk. `LegacyRealmImporterTests` asserts each `className()` to keep it
// that way.
//
// Equally: every stored property below must stay, including `sortNumber` and `lastModified`,
// which the SwiftData models deliberately drop. Realm treats a property present in the file but
// absent from the class as a schema change requiring a migration, so removing either one here
// would make the old store fail to open — the opposite of what dropping them was for.
//
// The store is opened read-write, not read-only: a file written by Realm 10.x needs its file
// format upgraded in place before Realm 20.x can read it, and a read-only configuration refuses
// to perform that upgrade.

/// Legacy singleton that held the user-defined checklist order. Dropped in the SwiftData
/// schema — ordering now lives on `Checklist.sortKey`.
@objc(Group)
class LegacyGroup: Object {
  @objc dynamic var id = NSUUID().uuidString

  let checklists = List<LegacyChecklist>()

  override nonisolated init() {
    super.init()
  }
}

@objc(Checklist)
class LegacyChecklist: Object {
  @objc dynamic var id = NSUUID().uuidString
  @objc dynamic var name: String = ""
  @objc dynamic var notes: String?
  /// Vestigial since v1.1.0 (ordering moved to `LegacyGroup.checklists`), but still on disk.
  @objc dynamic var sortNumber: Double = 0.0
  /// Never read or written by any shipped build, but still on disk.
  @objc dynamic var lastModified: Date = .init()

  let items = List<LegacyItem>()

  override nonisolated init() {
    super.init()
  }
}

@objc(Item)
class LegacyItem: Object {
  @objc dynamic var id = NSUUID().uuidString
  @objc dynamic var name: String = ""
  @objc dynamic var notes: String?
  @objc dynamic var statusRaw: Int = 0

  override nonisolated init() {
    super.init()
  }
}
