//
//  SettingsManager.swift
//  checklists
//
//  Created by Jimmy Ho on 8/11/19.
//

import Foundation

enum AppTheme: Int {
  // Note: Order and continuity of numbers matter; might be used in switch statements elsewhere.
  case defaultBougie = 0
  case extraBougie = 1
  case unicorns = 2
}

class SettingsManager {
  private(set) static var currentAppTheme: AppTheme = .defaultBougie

  static func setCurrentAppTheme(appTheme: AppTheme) {
    currentAppTheme = appTheme
    // TODO: notifications
  }

  static var versionBuildString: String = {
    let versionNumberString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "0.0.0"
    let buildNumberString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "0"
    #if DEBUG
      return "\(versionNumberString) (\(buildNumberString)) - DEBUG"
    #else
      return "\(versionNumberString) (\(buildNumberString))"
    #endif
  }()
}
