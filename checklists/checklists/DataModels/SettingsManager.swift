//
//  SettingsManager.swift
//  checklists
//
//  Created by Jimmy Ho on 8/11/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import Foundation

enum AppTheme: Int {
  // Note: Order and continuity of numbers matter; might be used in switch statements elsewhere.
  case defaultBougie = 0
  case extraBougie = 1
  case unicorns = 2
}

class SettingsManager {
  static private(set) var currentAppTheme: AppTheme = .defaultBougie

  static func setCurrentAppTheme(appTheme: AppTheme) {
    currentAppTheme = appTheme
    // TODO: notifications
  }
}
