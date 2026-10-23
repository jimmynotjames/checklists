#if DEBUG
  import Foundation
  import SwiftData

  /// Decodes a localized App Store screenshot catalog and materializes it in a disposable store.
  ///
  /// The JSON lives in the UI test bundle under `ScreenshotSeeds/<locale>.json`. The screenshot
  /// test selects the active locale, validates the catalog metadata, and passes the JSON to the app
  /// through `SEED_SCREENSHOTS_JSON`. `LaunchModeContainerFactory` accepts that value only while
  /// the process is running as a test, so screenshot data never reaches the real store or CloudKit.
  struct ScreenshotSeed: Decodable, Equatable {
    struct ChecklistFixture: Decodable, Equatable {
      let id: String
      let name: String
      let notes: String?
      let items: [ItemFixture]
    }

    struct ItemFixture: Decodable, Equatable {
      let name: String
      let notes: String?
      let isChecked: Bool
    }

    enum ValidationError: Error, Equatable {
      case unsupportedSchemaVersion(Int)
      case localeMismatch(expected: String, actual: String)
      case emptyPrimaryLocale
      case emptyChecklists
      case duplicateChecklistID(String)
      case emptyChecklistID
      case emptyChecklistName
      case emptyItemName
    }

    let schemaVersion: Int
    let locale: String
    let primaryLocale: String
    let checklists: [ChecklistFixture]

    static func decode(from json: String, expectedLocale: String) throws -> ScreenshotSeed {
      let seed = try JSONDecoder().decode(Self.self, from: Data(json.utf8))
      try seed.validate(expectedLocale: expectedLocale)
      return seed
    }

    func seed(into context: ModelContext) throws {
      var checklistSortKey = SortKeyReorder.step
      for fixture in checklists {
        let checklist = Checklist(
          id: fixture.id,
          name: fixture.name,
          notes: fixture.notes,
          sortKey: checklistSortKey,
        )
        context.insert(checklist)

        var itemSortKey = SortKeyReorder.step
        for itemFixture in fixture.items {
          let item = Item(
            name: itemFixture.name,
            notes: itemFixture.notes,
            sortKey: itemSortKey,
          )
          item.status = itemFixture.isChecked ? .checked : .unchecked
          context.insert(item)
          item.checklist = checklist
          itemSortKey += SortKeyReorder.step
        }

        checklistSortKey += SortKeyReorder.step
      }
      try context.saveChanges(operation: .sampleSeed)
    }

    private func validate(expectedLocale: String) throws {
      guard schemaVersion == 1 else {
        throw ValidationError.unsupportedSchemaVersion(schemaVersion)
      }
      guard locale == expectedLocale else {
        throw ValidationError.localeMismatch(expected: expectedLocale, actual: locale)
      }
      guard !primaryLocale.isEmpty else {
        throw ValidationError.emptyPrimaryLocale
      }
      guard !checklists.isEmpty else {
        throw ValidationError.emptyChecklists
      }

      var ids = Set<String>()
      for checklist in checklists {
        guard !checklist.id.isEmpty else { throw ValidationError.emptyChecklistID }
        guard ids.insert(checklist.id).inserted else {
          throw ValidationError.duplicateChecklistID(checklist.id)
        }
        guard !checklist.name.isEmpty else { throw ValidationError.emptyChecklistName }
        guard checklist.items.allSatisfy({ !$0.name.isEmpty }) else {
          throw ValidationError.emptyItemName
        }
      }
    }
  }
#endif
