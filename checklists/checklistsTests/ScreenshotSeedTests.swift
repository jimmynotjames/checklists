#if DEBUG
  //
  //  ScreenshotSeedTests.swift
  //  checklistsTests
  //

  @testable import checklists
  import Foundation
  import Testing

  /// Guards the localized screenshot fixture contract without changing the production sample data.
  @Suite("Screenshot seed fixture contract")
  struct ScreenshotSeedTests {
    @Test("the English catalog mirrors sample data with only the pre-trip completion override")
    func englishCatalogMirrorsSampleDataWithOnlyPreTripCompletionOverride() throws {
      let seed = try englishSeed()
      let sample = SampleData.generateFirstTimeLaunchChecklists()

      #expect(seed.schemaVersion == 1)
      #expect(seed.locale == "en-US")
      #expect(seed.primaryLocale == "en_US")
      #expect(seed.checklists.count == sample.count)

      for (checklistIndex, pair) in zip(seed.checklists, sample).enumerated() {
        let (screenshotChecklist, sampleChecklist) = pair
        #expect(screenshotChecklist.id == sampleChecklist.id)
        #expect(screenshotChecklist.name == sampleChecklist.name)
        #expect(screenshotChecklist.notes == sampleChecklist.notes)
        #expect(screenshotChecklist.items.count == sampleChecklist.items.count)

        for (itemIndex, itemPair) in zip(
          screenshotChecklist.items,
          sampleChecklist.items,
        ).enumerated() {
          let (screenshotItem, sampleItem) = itemPair
          #expect(screenshotItem.name == sampleItem.name)
          #expect(screenshotItem.notes == sampleItem.notes)

          let expectedChecked = checklistIndex == 2 && itemIndex < 3
            ? true
            : sampleItem.isChecked
          #expect(screenshotItem.isChecked == expectedChecked)
        }
      }

      #expect(seed.checklists.map(checkedCount) == [5, 4, 3])
    }

    @Test("a screenshot launch materializes the catalog in the test container")
    func screenshotLaunchMaterializesCatalogInTestContainer() throws {
      let json = try englishCatalogJSON()
      let result = try LaunchModeContainerFactory.make(
        arguments: [],
        environment: [
          "IS_TESTING": "1",
          LaunchModeContainerFactory.screenshotSeedJSONKey: json,
          LaunchModeContainerFactory.screenshotSeedLocaleKey: "en-US",
        ],
      )

      guard case .localFallback = result.backing else {
        Issue.record("Screenshot launch did not use the disposable local test backing.")
        return
      }
      let checklists = try result.container.mainContext.fetchChecklistsSorted()
      #expect(checklists.map(\.name) == [
        "Morning Routine",
        "Weekend Getaway Essentials",
        "Pre-Trip Checklist",
      ])
      #expect(checklists.map(\.sortKey) == [1.0, 2.0, 3.0])
      #expect(checklists.map(\.items.count) == [6, 12, 11])
      #expect(
        checklists.map { checklist in
          checklist.items.count(where: { $0.status == .checked })
        } == [5, 4, 3],
      )
    }

    @Test("an ordinary UI test launch still uses the production sample fixture")
    func ordinaryUITestLaunchStillUsesProductionSampleFixture() throws {
      let result = try LaunchModeContainerFactory.make(
        arguments: ["-UITests1"],
        environment: [:],
      )
      let checklists = try result.container.mainContext.fetchChecklistsSorted()

      #expect(
        checklists.map { checklist in
          checklist.items.count(where: { $0.status == .checked })
        } == [5, 4, 0],
      )
    }

    @Test("decoding a catalog against a mismatched locale throws")
    func catalogMustMatchActiveLocale() throws {
      let json = try englishCatalogJSON()

      #expect(throws: ScreenshotSeed.ValidationError.localeMismatch(expected: "fr-FR", actual: "en-US")) {
        try ScreenshotSeed.decode(from: json, expectedLocale: "fr-FR")
      }
    }

    @Test("every seed decodes and matches the English structure")
    func everySeedDecodesAndMatchesEnglishStructure() throws {
      let english = try englishSeed()
      let catalogs = try FileManager.default
        .contentsOfDirectory(at: seedsDirectory(), includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

      #expect(!catalogs.isEmpty)

      for url in catalogs {
        let locale = url.deletingPathExtension().lastPathComponent
        let json = try String(contentsOf: url, encoding: .utf8)
        let seed = try ScreenshotSeed.decode(from: json, expectedLocale: locale)

        #expect(seed.schemaVersion == 1, "\(locale): schemaVersion")
        // Seeding overrides -AppleLocale, so an empty value would silently leave
        // the simulator formatting dates and numbers as the source locale.
        #expect(!seed.primaryLocale.isEmpty, "\(locale): primaryLocale")

        // Only the words are localized. Everything structural is copied from
        // English so a reviewer comparing two locales sees the same lists.
        #expect(seed.checklists.map(\.id) == english.checklists.map(\.id), "\(locale): ids")
        #expect(
          seed.checklists.map(\.items.count) == english.checklists.map(\.items.count),
          "\(locale): item counts",
        )
        #expect(
          seed.checklists.map(checkedCount) == english.checklists.map(checkedCount),
          "\(locale): checked pattern",
        )
      }
    }

    private func englishSeed() throws -> ScreenshotSeed {
      try ScreenshotSeed.decode(from: englishCatalogJSON(), expectedLocale: "en-US")
    }

    private func seedsDirectory() -> URL {
      URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../checklistsUITests/ScreenshotSeeds")
        .standardizedFileURL
    }

    private func englishCatalogJSON() throws -> String {
      let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      let catalogURL = testsDirectory
        .appendingPathComponent("../checklistsUITests/ScreenshotSeeds/en-US.json")
        .standardizedFileURL
      return try String(contentsOf: catalogURL, encoding: .utf8)
    }

    private func checkedCount(_ fixture: ScreenshotSeed.ChecklistFixture) -> Int {
      fixture.items.count(where: \.isChecked)
    }
  }
#endif
