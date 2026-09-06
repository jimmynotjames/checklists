//
//  ICloudStatusLoaderTests.swift
//  checklistsTests
//

@testable import checklists
import CloudKit
import XCTest

/// Drives `ICloudStatusLoader.load(into:)` — the query + mapping half of the Settings iCloud
/// row — through injected account-status providers. `CKContainer` cannot be stubbed, which is
/// why the loader takes its query as an injectable closure in the first place.
///
/// Ported from budgets1's `simple-recurring-budgetsTests/Views/Settings/ICloudStatusLoaderTests.swift`
/// (Swift Testing) to XCTest. See the doc comment on `DataModelTests` for why this is
/// `nonisolated final class ... : XCTestCase` with `@MainActor` on each test method.
nonisolated final class ICloudStatusLoaderTests: XCTestCase {
  @MainActor func testAvailableProviderWritesAvailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: { .available })

    await loader.load(into: syncStatus)

    XCTAssertEqual(syncStatus.accountStatus, .available)
    XCTAssertEqual(syncStatus.rowState, .available)
  }

  @MainActor func testNoAccountWritesUnavailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: { .noAccount })

    await loader.load(into: syncStatus)

    XCTAssertEqual(syncStatus.accountStatus, .unavailable)
  }

  @MainActor func testCouldNotDetermineWritesUnavailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: { .couldNotDetermine })

    await loader.load(into: syncStatus)

    XCTAssertEqual(syncStatus.accountStatus, .unavailable)
  }

  @MainActor func testThrowingProviderWritesUnavailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: {
      throw CKError(.networkUnavailable)
    })

    await loader.load(into: syncStatus)

    XCTAssertEqual(syncStatus.accountStatus, .unavailable)
  }

  /// Re-query after a sign-in: the notification-driven path transitions unavailable →
  /// available (the live chain `SettingsViewController.observeSingleNotification` drives on
  /// CKAccountChanged / NSUbiquityIdentityDidChange).
  @MainActor func testReloadAfterSignInTransitionsToAvailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let signedIn = SignedInFlag()
    let loader = ICloudStatusLoader(accountStatus: {
      signedIn.value ? .available : .noAccount
    })

    await loader.load(into: syncStatus)
    XCTAssertEqual(syncStatus.accountStatus, .unavailable)

    signedIn.value = true
    await loader.load(into: syncStatus)
    XCTAssertEqual(syncStatus.accountStatus, .available)
    XCTAssertEqual(syncStatus.rowState, .available)
  }
}

/// Mutable flag the provider closure can capture (a closure can't capture an `inout`/`var` test
/// local across an `await` boundary).
@MainActor
private final class SignedInFlag {
  var value = false
}
