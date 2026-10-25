//
//  AccessibilityAuditUITest.swift
//  checklistsUITests
//

import XCTest

/// Xcode's accessibility audit on every screen, one test each, so a regression fails `make test-ui`.
///
/// Contrast is left out until Increase Contrast lands (#345). Anything the audit raises fails the test
/// unless it is in `knownIssues`.
class AccessibilityAuditUITest: XCTestCase {
  var app: XCUIApplication!

  /// The `FORCE_APPEARANCE` each launch passes; see `TestAppearanceOverride`.
  class var appearance: String {
    "light"
  }

  private static let auditTypes: XCUIAccessibilityAuditType = .all.subtracting(.contrast)

  /// One audit issue accepted on purpose. Every field given must match; `nil` matches anything.
  private struct KnownIssue {
    let screens: Set<String>?
    let types: XCUIAccessibilityAuditType
    let identifier: String?
    let label: String?
    let detailContains: String?
    /// Only on the alert's own text, or on an issue the audit raises without an element.
    let inAlert: Bool
    let reason: String

    init(
      screens: Set<String>? = nil,
      types: XCUIAccessibilityAuditType,
      identifier: String? = nil,
      label: String? = nil,
      detailContains: String? = nil,
      inAlert: Bool = false,
      reason: String,
    ) {
      self.screens = screens
      self.types = types
      self.identifier = identifier
      self.label = label
      self.detailContains = detailContains
      self.inAlert = inAlert
      self.reason = reason
    }
  }

  private static let knownIssues: [KnownIssue] = [
    KnownIssue(
      screens: ["copyCheckedItemsSheet"],
      types: .textClipped,
      identifier: "copyDestination.newChecklistName",
      reason: """
      Accepted: at the largest sizes a long translation of the placeholder may truncate. Wrapping it \
      would take a vertical field, where Return adds a line instead of committing.
      """,
    ),
    KnownIssue(
      screens: ["settings"],
      types: .textClipped,
      label: "iCloud Not Available",
      reason: "False positive: the status wraps at the largest sizes rather than clipping.",
    ),
    KnownIssue(
      screens: ["settings"],
      types: .dynamicType,
      label: "Info",
      reason: "False positive: the section header scales like the others in Settings.",
    ),
    KnownIssue(
      screens: ["resetAllAlert"],
      types: [.dynamicType, .elementDetection],
      inAlert: true,
      reason: "The alert's labels belong to UIAlertController, which the app can't restyle.",
    ),
    KnownIssue(
      screens: ["createSheet"],
      types: .sufficientElementDescription,
      detailContains: "TUIPredictionViewCell",
      reason: "The keyboard's suggestion bar is system UI; it shows up only some runs.",
    ),
    KnownIssue(
      screens: ["createSheet"],
      types: .sufficientElementDescription,
      identifier: "RecentPaste",
      reason: """
      The suggestion bar's "Paste from" cell is system UI, offering whatever the Mac last copied: the \
      simulator syncs the Mac's clipboard.
      """,
    ),
  ]

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  private func launch(locale: String? = nil) {
    app = XCUIApplication()
    app.launchArguments = ["-UITests1"] + (locale.map { ["-AppleLocale", $0] } ?? [])
    app.launchEnvironment["FORCE_APPEARANCE"] = Self.appearance
    app.launch()
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "Main checklists list did not appear after launch.")
  }

  /// Audits the current screen. An issue in `knownIssues` passes, logged with its reason; any other
  /// fails the test.
  ///
  /// A run that hits the audit's own time limit is retried once: that is the simulator being slow,
  /// not an issue on the screen, and a second timeout still fails.
  private func audit(_ screen: String) throws {
    do {
      try runAudit(screen)
    } catch let error as NSError where error.domain == Self.auditErrorDomain && error.code == Self.auditTimedOutCode {
      XCTContext.runActivity(named: "The audit timed out; running it once more.") { _ in }
      try runAudit(screen)
    }
  }

  /// `performAccessibilityAudit`'s "Audit failed to complete in time".
  private static let auditErrorDomain = "com.apple.xcode.xctest.accessibilityAudit"
  private static let auditTimedOutCode = -56

  private func runAudit(_ screen: String) throws {
    let alertText = Set(app.alerts.staticTexts.allElementsBoundByIndex.map { $0.label })
    try app.performAccessibilityAudit(for: Self.auditTypes) { issue in
      var identifier = ""
      var label = ""
      var hasElement = false
      if let element = issue.element, element.exists {
        hasElement = true
        identifier = element.identifier
        label = element.label
      }
      let known = Self.knownIssues.first { known in
        (known.screens?.contains(screen) ?? true)
          && !known.types.isDisjoint(with: issue.auditType)
          && (known.identifier == nil || known.identifier == identifier)
          && (known.label == nil || known.label == label)
          && (known.detailContains.map { issue.detailedDescription.contains($0) } ?? true)
          && (!known.inAlert || !hasElement || alertText.contains(label))
      }
      if let known {
        XCTContext.runActivity(named: "Known issue: \(issue.compactDescription). \(known.reason)") { _ in }
      }
      return known != nil
    }
  }

  // MARK: - Navigation

  private func tapButton(_ identifier: String) {
    let button = app.buttons[identifier]
    XCTAssertTrue(button.waitForExistence(timeout: 5), "\(identifier) didn't appear.")
    button.tap()
  }

  private func openChecklist(_ name: String) {
    let row = app.collectionViews.staticTexts[name]
    XCTAssertTrue(row.waitForExistence(timeout: 5), "\(name) isn't in the list.")
    row.tap()
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5), "The checklist didn't open.")
  }

  private func openOverflowMenu() {
    let moreButton = app.navigationBars.buttons["checklist.more"]
    XCTAssertTrue(moreButton.waitForExistence(timeout: 5), "Overflow menu button didn't appear.")
    moreButton.tap()
  }

  // MARK: - Checklists list

  func testChecklistsList() throws {
    launch()
    try audit("checklistsList")
  }

  func testChecklistsListEditMode() throws {
    launch()
    tapButton("toolbar.more")
    tapButton("toolbar.edit")
    // Once Edit mode's bar is up, a row tap selects instead of opening.
    XCTAssertTrue(app.buttons["editBar.delete"].waitForExistence(timeout: 5), "Edit mode didn't start.")
    app.collectionViews.staticTexts["Morning Routine"].tap()
    try audit("checklistsListEditMode")
  }

  func testResetAllAlert() throws {
    launch()
    tapButton("toolbar.more")
    tapButton("toolbar.resetAll")
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "Reset All confirmation didn't appear.")
    try audit("resetAllAlert")
  }

  func testMainMenu() throws {
    launch()
    tapButton("toolbar.mainMenu")
    XCTAssertTrue(app.buttons["mainMenu.settings"].waitForExistence(timeout: 5), "Main menu didn't open.")
    try audit("mainMenu")
  }

  func testSettings() throws {
    launch()
    tapButton("toolbar.mainMenu")
    tapButton("mainMenu.settings")
    XCTAssertTrue(app.links["Privacy Policy"].waitForExistence(timeout: 5), "Settings didn't open.")
    try audit("settings")
  }

  func testCreateSheet() throws {
    launch()
    tapButton("toolbar.addChecklist")
    XCTAssertTrue(app.tables["ChecklistTableView"].waitForExistence(timeout: 5), "The create sheet didn't open.")
    // The name field takes focus as the sheet opens; audit once the keyboard is up, not mid-way.
    app.waitForSoftwareKeyboard("The keyboard didn't come up.")
    try audit("createSheet")
  }

  // MARK: - Checklist screen

  func testChecklist() throws {
    launch()
    openChecklist("Weekend Getaway Essentials")
    try audit("checklist")
  }

  // Deliberately no audit of the checklist screen while an item is being edited. The audit's
  // Dynamic Type check changes the text size mid-audit, which ends the edit, and then
  // intermittently flags a row caught mid-relayout as "partially unsupported": a flake, not a
  // finding, and the editing state goes unaudited anyway. What only that state shows, an item's
  // expanded empty notes field, is covered by functional UI tests that type into it, not by an
  // audit; `testCreateSheet` audits the keyboard and the editing Done.

  func testOverflowMenu() throws {
    launch()
    openChecklist("Weekend Getaway Essentials")
    openOverflowMenu()
    XCTAssertTrue(app.buttons["checklist.menu.reorderItems"].waitForExistence(timeout: 5), "The overflow menu didn't open.")
    try audit("overflowMenu")
  }

  func testReorderItemsMode() throws {
    launch()
    openChecklist("Weekend Getaway Essentials")
    openOverflowMenu()
    tapButton("checklist.menu.reorderItems")
    XCTAssertTrue(app.buttons["checklist.reorderDone"].waitForExistence(timeout: 5), "Reorder Items mode didn't start.")
    try audit("reorderItemsMode")
  }

  /// Morning Routine has checked items to copy.
  func testCopyCheckedItemsSheet() throws {
    launch()
    openChecklist("Morning Routine")
    openOverflowMenu()
    let copyEntry = app.buttons["Copy Checked Items to…"]
    XCTAssertTrue(copyEntry.waitForExistence(timeout: 5), "Copy Checked Items menu entry didn't appear.")
    copyEntry.tap()
    XCTAssertTrue(app.buttons["copyDestination.createNewChecklist"].waitForExistence(timeout: 5), "The destination picker didn't open.")
    try audit("copyCheckedItemsSheet")
  }

  // MARK: - Consent sheet

  /// Only a strict-consent region asks, so the locale is forced, as `AnalyticsConsentUITest` does.
  func testAnalyticsConsentSheet() throws {
    launch(locale: "de_DE")
    openChecklist("Morning Routine")
    XCTAssertTrue(app.buttons["analyticsConsentSheet.accept"].waitForExistence(timeout: 5), "The consent sheet didn't appear.")
    try audit("analyticsConsentSheet")
  }
}
