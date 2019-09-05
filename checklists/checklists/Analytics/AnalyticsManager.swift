//
//  AnalyticsManager.swift
//  checklists
//
//  Created by Jimmy Ho on 9/4/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation

struct AnalyticsManager {
  // MARK: - Page View Analytics
  static func logChecklistsViewed(numChecklists: Int) {
    Flurry.logEvent("checklists_viewed", withParameters: ["num_checklists": numChecklists])
  }
  static func logChecklistViewed(numItems: Int, numItemsWithNotes: Int) {
    Flurry.logEvent("checklist_viewed", withParameters: ["num_items": numItems, "num_items_with_notes": numItemsWithNotes])
  }
  static func logDonatePageViewed() {
    Flurry.logEvent("donate_page_viewed")
  }
  static func logSettingsViewed() {
    Flurry.logEvent("settings_viewed")
  }
  static func logMainMenuViewed() {
    Flurry.logEvent("main_menu_viewed")
  }

  // MARK: - Other Navigation Analytics
  static func logRateInAppStore() {
    Flurry.logEvent("rate_in_app_store")
  }
  static func logSendFeedback() {
    Flurry.logEvent("send_feedback")
  }
  static func logViewPrivacyPolicy() {
    Flurry.logEvent("view_privacy_policy")
  }

  // MARK: - Donation Analytics
  static func logDonation(productId: String) {
    Flurry.logEvent("donate/purchase", withParameters: [ "product_id": productId ])
  }
  static func logPurchaseError(errorMessage: String) {
    Flurry.logEvent("donate/purchase_error", withParameters: [ "error": errorMessage ])
  }
  static func logProductLoadingError(errorMessage: String) {
    Flurry.logEvent("donate/error_loading_products", withParameters: [ "error": errorMessage ])
  }
}
