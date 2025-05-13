//
//  ChecklistsApp.swift
//  checklists
//
//  Created by Jimmy Ho on 11/21/24.
//  Copyright © 2024 Jimmy Ho. All rights reserved.
//

import SwiftUI
import RealmSwift

private let launchedAtLeastOnceKey = "launchedAtLeastOnce"
private let appVersionKey = "appVersionKey"

@main
struct ChecklistsApp: SwiftUI.App {

  init() {
    AnalyticsManager.appLaunched()
    initializeAppSettings()
  }

  var body: some Scene {
    WindowGroup {
      ChecklistsView(group: DBManager.getGroup())
    }
  }

  private func initializeAppSettings() {
    let isFirstTimeLaunch = !UserDefaults.standard.bool(forKey: launchedAtLeastOnceKey)
    if isFirstTimeLaunch {
      SampleData.insertFirstTimeLaunchDataV1_1()
      UserDefaults.standard.set(true, forKey: launchedAtLeastOnceKey)
    }
    UserDefaults.standard.set(SettingsManager.appVersionString, forKey: appVersionKey)
    DBManager.migrateToAppVersion1_1_1()
    DBManager.migrateDatabaseToUseGroupObjectIfNecessary()

    // For dev manual testing/debugging
    // TODO: Comment out below code before prod release.
    #if DEBUG
    // SampleData.clearDatabase()
    // SampleData.insertFirstTimeLaunchData()
    // SampleData.insertTestData()
    print("appVersion: \(UserDefaults.standard.string(forKey: appVersionKey) ?? "[Not Found]")")
    #endif

    // For UITests
    #if DEBUG
    if CommandLine.arguments.contains("-UITests1") {
      print("Injecting Test Data for UITests1")
      SampleData.clearDatabase()
      SampleData.insertFirstTimeLaunchDataV1_1()
    }
    #endif
  }
}
