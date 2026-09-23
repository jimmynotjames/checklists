import XCTest

/// **Ad-hoc** localized large-type screenshot capture — NOT part of `make test-ui` or the gate.
///
/// Drives the app in 13 locales at forced `.xxxLarge` and saves a screenshot of each key screen as a
/// `.keepAlways` attachment named `<lang>__<screen>`. It makes **no layout assertions** — it never
/// "fails" on truncation; a human or Claude inspects the screenshots (see
/// `scripts/translation-accessibility-size-check/`). Runs only when the runner `-only-testing`s it.
///
/// Navigation is locale-invariant (accessibility identifiers and `cells.firstMatch`); the type size is
/// forced via the `FORCE_DYNAMIC_TYPE` env hook, because the standard
/// `-UIPreferredContentSizeCategoryName` launch argument rendered at the default size on the iOS 26.x
/// simulator. One test method per language so xcodebuild can fan them across simulator clones.
///
/// **Depends on existing code (don't break these without updating this capture):**
/// - The `-UITests1` launch argument and its production sample fixture (three checklists), which is
///   what gives every locale the same rows to photograph.
/// - Four `.accessibilityIdentifier(...)` handles this is currently the only consumer of:
///   `toolbar.mainMenu`, `toolbar.checklistsMenu`, `toolbar.addChecklist`, `checklistRow.delete`
///   (ChecklistsView) and `mainMenu.settings` (MainMenuView). Renaming one breaks navigation here.
/// - The row's trailing swipe reveals two buttons: `checklistRow.duplicate` beside
///   `checklistRow.delete`.
/// - `analyticsConsentSheet.decline`, shared with `AnalyticsConsentUITest`.
/// - `TestDynamicTypeOverride` (the `FORCE_DYNAMIC_TYPE` hook), applied at the app root and again on
///   `RootView`'s sheet, since a sheet does not inherit the root's `dynamicTypeSize`.
/// - The runner `scripts/translation-accessibility-size-check/run.sh`, which `-only-testing`s this
///   class and relies on the `<lang>__<screen>` attachment names.
final class LocalizationScreenshotCapture: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = true
  }

  // MARK: - Languages

  //
  // Thirteen, chosen for what they stress rather than for market size: the three
  // right-to-left scripts, the scripts with tall or connected glyphs, and the
  // languages whose words run longest against a fixed-width control.

  /// German and Finnish carry the longest words; a fixed-width control breaks here first.
  @MainActor func testCaptureGerman() {
    captureAll("de")
  }

  @MainActor func testCaptureFinnish() {
    captureAll("fi")
  }

  @MainActor func testCaptureRussian() {
    captureAll("ru")
  }

  /// Thai, Vietnamese, and the Indic scripts stack diacritics above and below the line,
  /// so a row sized for Latin text clips them.
  @MainActor func testCaptureThai() {
    captureAll("th")
  }

  @MainActor func testCaptureVietnamese() {
    captureAll("vi")
  }

  @MainActor func testCaptureHindi() {
    captureAll("hi")
  }

  @MainActor func testCaptureTamil() {
    captureAll("ta")
  }

  @MainActor func testCaptureBengali() {
    captureAll("bn")
  }

  /// The three right-to-left scripts. Urdu is also Nastaliq, which is taller than Naskh.
  @MainActor func testCaptureArabic() {
    captureAll("ar")
  }

  @MainActor func testCaptureHebrew() {
    captureAll("he")
  }

  @MainActor func testCaptureUrdu() {
    captureAll("ur")
  }

  /// CJK: dense glyphs that stay legible only above a certain rendered size.
  @MainActor func testCaptureJapanese() {
    captureAll("ja")
  }

  @MainActor func testCaptureChineseSimplified() {
    captureAll("zh-Hans")
  }

  // MARK: - Per-language sweep

  @MainActor private func captureAll(_ lang: String) {
    capture("01-list", lang) { _ in true }

    capture("02-menu", lang) { app in
      self.tap(app, "toolbar.mainMenu")
    }

    capture("03-settings", lang) { app in
      guard self.tap(app, "toolbar.mainMenu"),
            self.tap(app, "mainMenu.settings")
      else { return false }
      return app.switches.firstMatch.waitForExistence(timeout: 8)
    }

    capture("04-detail", lang) { app in
      app.cells.firstMatch.tap()
      // The detail screen is the UIKit one; its name field is the reliable marker.
      return app.textFields["checklistNameField"].waitForExistence(timeout: 8)
        || app.textViews["itemNameTextView"].firstMatch.waitForExistence(timeout: 4)
    }

    capture("05-reset-menu", lang) { app in
      self.tap(app, "toolbar.checklistsMenu")
    }

    capture("06-delete-confirm", lang) { app in
      let row = app.cells.firstMatch
      guard row.waitForExistence(timeout: 8) else { return false }
      // The swipe is mirrored under right-to-left: `.trailing` swipe actions sit on
      // the leading (left) edge there, so a hardcoded swipeLeft reveals nothing.
      // This failed in exactly ar, he, and ur before the direction was made
      // locale-aware.
      if Self.rightToLeft.contains(lang) {
        row.swipeRight()
      } else {
        row.swipeLeft()
      }
      // By identifier, not by position: the revealed swipe-action buttons are not
      // reliably enumerable straight after the swipe.
      guard self.tap(app, "checklistRow.delete") else { return false }
      return app.alerts.firstMatch.waitForExistence(timeout: 8)
    }

    capture("07-new-checklist", lang) { app in
      guard self.tap(app, "toolbar.addChecklist") else { return false }
      return app.textFields["checklistNameField"].waitForExistence(timeout: 8)
    }
  }

  /// Locales whose layout direction mirrors the swipe gesture.
  private static let rightToLeft: Set<String> = ["ar", "he", "ur"]

  // MARK: - Helpers

  /// Tap a control by its accessibility identifier (locale-invariant). Returns false if not found.
  @MainActor private func tap(_ app: XCUIApplication, _ identifier: String) -> Bool {
    let element = app.descendants(matching: .any)[identifier].firstMatch
    guard element.waitForExistence(timeout: 8) else { return false }
    element.tap()
    return true
  }

  /// Launch in `lang` at forced xxxLarge against the standard UI-test fixture.
  @MainActor private func launch(_ lang: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-UITests1", "-AppleLanguages", "(\(lang))", "-AppleLocale", localeID(lang)]
    app.launchEnvironment["IS_TESTING"] = "1"
    app.launchEnvironment["FORCE_DYNAMIC_TYPE"] = "xxxLarge"
    app.launch()
    return app
  }

  /// Attach a `.keepAlways` screenshot named `<lang>__<screen>` (run.sh renames by this).
  @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  /// Clear the analytics consent sheet if this region gets one, photographing it on the way past.
  ///
  /// Handled by presence rather than by a hardcoded list of strict regions: the list lives in the
  /// app and would rot here, and the sheet is worth a shot in every locale that shows it — it is the
  /// densest text in the app and the first thing a new user in those regions reads.
  @MainActor private func clearConsentIfPresented(_ app: XCUIApplication, _ lang: String) {
    let decline = app.buttons["analyticsConsentSheet.decline"].firstMatch
    guard decline.waitForExistence(timeout: 4) else { return }
    attach(app, "\(lang)__04a-consent")
    decline.tap()
    _ = decline.waitForNonExistence(timeout: 4)
  }

  /// Launch in `lang` at forced xxxLarge, navigate, and attach a screenshot.
  @MainActor private func capture(
    _ screen: String,
    _ lang: String,
    navigate: (XCUIApplication) -> Bool
  ) {
    let app = launch(lang)
    clearConsentIfPresented(app, lang)
    guard navigate(app) else {
      XCTFail("\(lang) \(screen): could not reach the screen")
      app.terminate()
      return
    }
    attach(app, "\(lang)__\(screen)")
    app.terminate()
  }

  /// Region for `-AppleLocale`, mirroring `fastlane/screenshot-config.json`'s region column so a
  /// screenshot formats its dates and numbers the way that storefront's users see them.
  private func localeID(_ lang: String) -> String {
    ["de": "de_DE", "fi": "fi_FI", "ru": "ru_RU", "th": "th_TH",
     "vi": "vi_VN", "ar": "ar_SA", "he": "he_IL", "ja": "ja_JP",
     "zh-Hans": "zh_Hans_CN", "hi": "hi_IN", "ur": "ur_PK",
     "ta": "ta_IN", "bn": "bn_BD"][lang] ?? "\(lang)_\(lang.uppercased())"
  }
}
