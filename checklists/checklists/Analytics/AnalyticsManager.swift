//
//  AnalyticsManager.swift
//  checklists
//
//  Created by Jimmy Ho on 9/4/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation

struct AnalyticsManager {
  // MARK: - Session
  static func appLaunched() {
    #if DEBUG
    #else
    let sessionBuilder = FlurrySessionBuilder.init().withCrashReporting(true)?.withLogLevel(FlurryLogLevelCriticalOnly)?.withAppVersion(SettingsManager.versionBuildString)
    Flurry.startSession("BQTJY88YMP27MFMRRJTY", with: sessionBuilder)
    #endif
  }

  // MARK: - Utilities
  static func logEvent(_ eventName: String, withParameters params: [AnyHashable: Any]? = nil) {
    #if DEBUG
    #else
    Flurry.logEvent(eventName, withParameters: params)
    #endif
  }

  static func truncatedString(_ s: String) -> String {
    return String(s.prefix(127)) // Limit by Flurry on param values is 255, but not sure if they're doing UTF-8, so being cautious.
  }

  // MARK: - Page View Analytics
  static func logChecklistsViewed(numChecklists: Int) { logEvent("checklists_viewed", withParameters: ["num_checklists": numChecklists]) }
  static func logChecklistViewed(checklistName: String,
                                 checklistNotesLength: Int,
                                 numItems: Int,
                                 numItemsWithNotes: Int) {
    let params: [ AnyHashable: Any ] = [
      "name": checklistName,
      "notesLength": checklistNotesLength,
      "num_items": numItems,
      "num_items_with_notes": numItemsWithNotes
    ]
    logEvent("checklist_viewed", withParameters: params)
  }
  static func logDonatePageViewed() { logEvent("donate_page_viewed")  }
  static func logSettingsViewed() { logEvent("settings_viewed") }
  static func logMainMenuViewed() { logEvent("main_menu_viewed") }

  // MARK: - Other Navigation Analytics
  static func logRateInAppStore() { logEvent("rate_in_app_store") }
  static func logSendFeedback() { logEvent("send_feedback") }
  static func logViewPrivacyPolicy() { logEvent("view_privacy_policy") }

  // MARK: - General User Actions
  static func logNewChecklist() { logEvent("create_new_checklist") }
  static func logResetChecklist() { logEvent("reset_checklist") }

  // MARK: - Donation Analytics
  static func logDonation(productId: String) { logEvent("donate/purchase", withParameters: [ "product_id": productId ]) }
  static func logPurchaseError(errorMessage: String) { logEvent("donate/purchase_error", withParameters: [ "error": truncatedString(errorMessage) ]) }
  static func logProductLoadingError(errorMessage: String) { logEvent("donate/error_loading_products", withParameters: [ "error": truncatedString(errorMessage) ]) }

  // MARK: - Error Logging
  static func logRealmFailure(errorMessage: String) { logEvent("realm/fatal_error", withParameters: [ "error": truncatedString(errorMessage) ]) }
  static func logRealmWriteFailure(errorMessage: String) { logEvent("realm/write_error", withParameters: [ "error": truncatedString(errorMessage) ]) }

  // MARK: - Device info analytics
  // Overall ratio of iPad versus iPhone can be found in App Store Connect Analytics, so leaving that out here.
  static func logDeviceOrientationChange() {
    let orientation = UIDevice.current.orientation
    guard orientation.isPortrait || orientation.isLandscape else { return } // When it's laid flat, it will also fire, and we're filtering it out here.
    // To be technical, our app doesn't support upside down portrait, but this will log it. Not worth extra code to fix.
    let orientationString = orientation.isPortrait ? "portrait" : "landscape"

    let uiIdiom: String
    switch UIDevice.current.userInterfaceIdiom {
    case .phone: uiIdiom = "iphone"
    case .pad: uiIdiom = "ipad"
    case .carPlay: uiIdiom = "carplay"
    case .tv: uiIdiom = "tv"
    case .unspecified: uiIdiom = "unspecified"
    default: uiIdiom = "unknown"
    }
    logEvent("orientation_changed", withParameters: [ "orientation": orientationString, "ui_idiom": uiIdiom ])
  }
}
