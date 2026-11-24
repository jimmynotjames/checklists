import Foundation
import UIKit
import XCTest

/// App Store marketing screenshot capture for fastlane `snapshot`.
///
/// This class is omitted from every UI test run (`scripts/ci/ui_shards.py`) and also skips unless the screenshot runner
/// explicitly sets `RUN_APP_STORE_SCREENSHOTS=1`. The app receives localized fixture JSON only
/// through its DEBUG test launch path, which always uses a disposable in-memory SwiftData store.
final class AppStoreScreenshots: XCTestCase {
  private static let preTripChecklistID = "C4EC1157-0000-4000-A000-000000000003"

  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["RUN_APP_STORE_SCREENSHOTS"] == "1",
      "App Store screenshots run only through the explicit screenshot workflow.",
    )
    continueAfterFailure = false
  }

  @MainActor func testCaptureAppStoreScreenshots() throws {
    guard !(ProcessInfo.processInfo.environment["SCREENSHOT_CACHE_DIR"] ?? "").isEmpty else {
      return XCTFail("SCREENSHOT_CACHE_DIR is required for the screenshot workflow.")
    }

    let app = XCUIApplication()
    setupSnapshot(app)

    let locale = activeLocale()
    let catalog = try loadCatalog(for: locale)
    XCTAssertEqual(catalog.metadata.schemaVersion, 1, "Unsupported screenshot catalog schema.")
    XCTAssertEqual(
      catalog.metadata.locale,
      locale,
      "Screenshot catalog locale does not match the active snapshot locale.",
    )
    XCTAssertFalse(catalog.metadata.primaryLocale.isEmpty, "Screenshot catalog primaryLocale is empty.")

    app.launchEnvironment["IS_TESTING"] = "1"
    app.launchEnvironment["SEED_SCREENSHOTS_JSON"] = catalog.json
    app.launchEnvironment["SCREENSHOT_SEED_LOCALE"] = locale
    // The listing shows the light appearance; see `TestAppearanceOverride`.
    app.launchEnvironment["FORCE_APPEARANCE"] = "light"
    app.launchArguments += [
      "-UIPreferredContentSizeCategoryName",
      UIContentSizeCategory.large.rawValue,
    ]
    overrideAppleLocale(app, with: catalog.metadata.primaryLocale)
    XCUIDevice.shared.orientation = .portrait

    app.launch()
    let list = app.collectionViews.firstMatch
    XCTAssertTrue(list.waitForExistence(timeout: 30), "Main checklists list did not appear.")

    let preTripRow = app.buttons["checklistRow.\(Self.preTripChecklistID)"]
    XCTAssertTrue(preTripRow.waitForExistence(timeout: 10), "Pre-Trip checklist row did not appear.")
    snapshot("01_checklists")

    preTripRow.tap()
    let detailTable = app.tables["ChecklistTableView"]
    XCTAssertTrue(
      detailTable.waitForExistence(timeout: 15),
      "Pre-Trip checklist detail did not appear.",
    )
    assertConsentSheetIsAbsent(in: app)
    snapshot("02_pre_trip")
  }

  /// The seeded opt-out is the primary invariant. This bounded check makes a broken invariant
  /// fail the capture workflow visibly if either consent action appears asynchronously.
  @MainActor private func assertConsentSheetIsAbsent(in app: XCUIApplication) {
    let accept = app.buttons["analyticsConsentSheet.accept"]
    let decline = app.buttons["analyticsConsentSheet.decline"]
    XCTAssertFalse(
      accept.waitForExistence(timeout: 3),
      "Analytics consent appeared over the screenshot detail screen.",
    )
    XCTAssertFalse(
      decline.waitForExistence(timeout: 1),
      "Analytics consent appeared over the screenshot detail screen.",
    )
  }

  @MainActor private func activeLocale() -> String {
    if let explicit = ProcessInfo.processInfo.environment["SCREENSHOT_LOCALE"], !explicit.isEmpty {
      return explicit
    }
    return Snapshot.deviceLanguage.isEmpty ? "en-US" : Snapshot.deviceLanguage
  }

  @MainActor private func loadCatalog(for locale: String) throws -> Catalog {
    let bundle = Bundle(for: AppStoreScreenshots.self)
    let candidates = [
      bundle.url(forResource: locale, withExtension: "json", subdirectory: "ScreenshotSeeds"),
      bundle.url(forResource: locale, withExtension: "json"),
    ]
    let url = try XCTUnwrap(
      candidates.compactMap(\.self).first,
      "No ScreenshotSeeds/\(locale).json catalog is bundled for the active locale.",
    )
    let data = try Data(contentsOf: url)
    let metadata = try JSONDecoder().decode(CatalogMetadata.self, from: data)
    let json = try XCTUnwrap(String(data: data, encoding: .utf8), "Screenshot catalog is not UTF-8.")
    return Catalog(json: json, metadata: metadata)
  }

  /// Replace the locale inserted by SnapshotHelper so the region-qualified catalog locale wins.
  @MainActor private func overrideAppleLocale(_ app: XCUIApplication, with locale: String) {
    if let index = app.launchArguments.firstIndex(of: "-AppleLocale"),
       index + 1 < app.launchArguments.count {
      app.launchArguments[index + 1] = locale
    } else {
      app.launchArguments += ["-AppleLocale", locale]
    }
  }

  private struct Catalog {
    let json: String
    let metadata: CatalogMetadata
  }

  private struct CatalogMetadata: Decodable {
    let schemaVersion: Int
    let locale: String
    let primaryLocale: String
  }
}
