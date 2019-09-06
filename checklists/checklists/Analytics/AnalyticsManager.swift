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
}
