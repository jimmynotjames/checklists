#if DEBUG
  //
  //  ScreenshotSeedTests.swift
  //  checklistsTests
  //

  @testable import checklists
  import Foundation
  import XCTest

  /// Guards the localized screenshot fixture contract without changing the production sample data.
  ///
  /// See the doc comment on `DataModelTests` for why this class is `nonisolated` at the type level
  /// with individual `@MainActor` test methods.
  nonisolated final class ScreenshotSeedTests: XCTestCase {
    @MainActor func testEnglishCatalogMirrorsSampleDataWithOnlyPreTripCompletionOverride() throws {
      let seed = try englishSeed()
      let sample = SampleData.generateFirstTimeLaunchChecklists()

      XCTAssertEqual(seed.schemaVersion, 1)
      XCTAssertEqual(seed.locale, "en-US")
      XCTAssertEqual(seed.primaryLocale, "en_US")
      XCTAssertEqual(seed.checklists.count, sample.count)

      for (checklistIndex, pair) in zip(seed.checklists, sample).enumerated() {
        let (screenshotChecklist, sampleChecklist) = pair
        XCTAssertEqual(screenshotChecklist.id, sampleChecklist.id)
        XCTAssertEqual(screenshotChecklist.name, sampleChecklist.name)
        XCTAssertEqual(screenshotChecklist.notes, sampleChecklist.notes)
        XCTAssertEqual(screenshotChecklist.items.count, sampleChecklist.items.count)

        for (itemIndex, itemPair) in zip(
          screenshotChecklist.items,
          sampleChecklist.items
        ).enumerated() {
          let (screenshotItem, sampleItem) = itemPair
          XCTAssertEqual(screenshotItem.name, sampleItem.name)
          XCTAssertEqual(screenshotItem.notes, sampleItem.notes)

          let expectedChecked = checklistIndex == 2 && itemIndex < 3
            ? true
            : sampleItem.isChecked
          XCTAssertEqual(screenshotItem.isChecked, expectedChecked)
        }
      }

      XCTAssertEqual(seed.checklists.map(checkedCount), [5, 4, 3])
    }

    @MainActor func testScreenshotLaunchMaterializesCatalogInTestContainer() throws {
      let json = try englishCatalogJSON()
      let result = try LaunchModeContainerFactory.make(
        arguments: [],
        environment: [
          "IS_TESTING": "1",
          LaunchModeContainerFactory.screenshotSeedJSONKey: json,
          LaunchModeContainerFactory.screenshotSeedLocaleKey: "en-US",
        ]
      )

      guard case .localFallback = result.backing else {
        return XCTFail("Screenshot launch did not use the disposable local test backing.")
      }
      let checklists = try result.container.mainContext.fetchChecklistsSorted()
      XCTAssertEqual(checklists.map(\.name), [
        "Morning Routine",
        "Weekend Getaway Essentials",
        "Pre-Trip Checklist",
      ])
      XCTAssertEqual(checklists.map(\.sortKey), [1.0, 2.0, 3.0])
      XCTAssertEqual(checklists.map(\.items.count), [6, 12, 11])
      XCTAssertEqual(
        checklists.map { checklist in
          checklist.items.count(where: { $0.status == .checked })
        },
        [5, 4, 3]
      )
    }

    @MainActor func testOrdinaryUITestLaunchStillUsesProductionSampleFixture() throws {
      let result = try LaunchModeContainerFactory.make(
        arguments: ["-UITests1"],
        environment: [:]
      )
      let checklists = try result.container.mainContext.fetchChecklistsSorted()

      XCTAssertEqual(
        checklists.map { checklist in
          checklist.items.count(where: { $0.status == .checked })
        },
        [5, 4, 0]
      )
    }

    @MainActor func testCatalogMustMatchActiveLocale() throws {
      let json = try englishCatalogJSON()

      XCTAssertThrowsError(try ScreenshotSeed.decode(from: json, expectedLocale: "fr-FR")) { error in
        XCTAssertEqual(
          error as? ScreenshotSeed.ValidationError,
          .localeMismatch(expected: "fr-FR", actual: "en-US")
        )
      }
    }

    @MainActor private func englishSeed() throws -> ScreenshotSeed {
      try ScreenshotSeed.decode(from: englishCatalogJSON(), expectedLocale: "en-US")
    }

    private func englishCatalogJSON() throws -> String {
      let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      let catalogURL = testsDirectory
        .appendingPathComponent("../checklistsUITests/ScreenshotSeeds/en-US.json")
        .standardizedFileURL
      return try String(contentsOf: catalogURL, encoding: .utf8)
    }

    @MainActor private func checkedCount(_ fixture: ScreenshotSeed.ChecklistFixture) -> Int {
      fixture.items.count(where: \.isChecked)
    }
  }
#endif
