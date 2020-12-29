//
//  AppDelegate.swift
//  checklists
//x
//  Created by Jimmy Ho on 5/7/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit
import RealmSwift
import StoreKit

private let launchedAtLeastOnceKey = "launchedAtLeastOnce"
private let appVersionKey = "appVersionKey"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

  var window: UIWindow?

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    AnalyticsManager.appLaunched()

    // From the Apple docs, I'm slightly worried about power usage by turning this on, but can find nothing online saying this is a power hog.
    // TODO-DEFERRED: Nevertheless, once we collect stats on landscape/portrait, maybe remove this?
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)

    updateNavigationBarAppearance()
    SKPaymentQueue.default().add(StoreManager.shared)

    #if DEBUG
    // SampleData.clearDatabase() // TODO: Comment out before prod release
    #endif

    let isFirstTimeLaunch = !UserDefaults.standard.bool(forKey: launchedAtLeastOnceKey)
    if isFirstTimeLaunch {
      SampleData.insertFirstTimeLaunchDataV1_1()
      UserDefaults.standard.set(true, forKey: launchedAtLeastOnceKey)
      UserDefaults.standard.set("1.1", forKey: appVersionKey)
    } else {
      // v1.0 didn't have a Group object, so if that's the case, then this is first-time launch of app upgrade to v1.1, and instantiate one.
      if DBManager.realm.objects(Group.self).isEmpty {
        UserDefaults.standard.set("1.1", forKey: appVersionKey) // We never set this key for v1.0 so make sure it's set for v1.1 onwards.
        migrateDatabase1_1()
      }
    }

    #if DEBUG
    // SampleData.insertFirstTimeLaunchData() // TODO: Comment out before prod release
    // SampleData.insertTestData2() // TODO: Comment out before prod release
    // print("appVersion: \(UserDefaults.standard.string(forKey: appVersionKey) ?? "[Not Found]")")
    #endif

    return true
  }

  private func updateNavigationBarAppearance() {
    let navigationBarAppearance = UINavigationBar.appearance()
    navigationBarAppearance.tintColor = Colors.teal
    navigationBarAppearance.setBackgroundImage(UIImage(), for: .default)
    navigationBarAppearance.shadowImage = UIImage()
    navigationBarAppearance.isTranslucent = false
    navigationBarAppearance.barTintColor = Colors.defaultBackground
    navigationBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: Colors.teal]
  }

  // For migrating from v1.0 to v1.1. Updating scheme from using sortNumber to using the Group object to hold a ordered list.
  private func migrateDatabase1_1() {
    let realm = DBManager.realm
    let group = Group()
    DBManager.write {
      realm.add(group)
      let checklists = realm.objects(Checklist.self).sorted(byKeyPath: "sortNumber")
      for checklist in checklists {
        group.checklists.append(checklist)
      }
    }
  }

  @objc func orientationChanged(notification: NSNotification!) {
    AnalyticsManager.logDeviceOrientationChange()
  }

  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
    SKPaymentQueue.default().remove(StoreManager.shared)
    UIDevice.current.endGeneratingDeviceOrientationNotifications() // Honestly, I doubt this is necessary, but whatevs.
  }
}

