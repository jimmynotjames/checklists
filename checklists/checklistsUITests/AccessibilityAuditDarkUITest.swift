//
//  AccessibilityAuditDarkUITest.swift
//  checklistsUITests
//

import XCTest

/// Every audit in `AccessibilityAuditUITest`, run again in dark appearance.
final class AccessibilityAuditDarkUITest: AccessibilityAuditUITest {
  override static var appearance: String {
    "dark"
  }
}
