//
//  ICloudStatusLoaderTests.swift
//  checklistsTests
//

@testable import checklists
import CloudKit
import Testing

/// Drives `ICloudStatusLoader.load(into:)` — the query + mapping half of the Settings iCloud
/// row — through injected account-status providers. `CKContainer` cannot be stubbed, which is
/// why the loader takes its query as an injectable closure in the first place.
///
/// Ported from budgets1's `ICloudStatusLoaderTests` suite of the same name.
@Suite("ICloudStatusLoader account status mapping")
struct ICloudStatusLoaderTests {
  @Test("an available provider writes available")
  func availableProviderWritesAvailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: { .available })

    await loader.load(into: syncStatus)

    #expect(syncStatus.accountStatus == .available)
    #expect(syncStatus.rowState == .available)
  }

  @Test("no account writes unavailable")
  func noAccountWritesUnavailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: { .noAccount })

    await loader.load(into: syncStatus)

    #expect(syncStatus.accountStatus == .unavailable)
  }

  @Test("could not determine writes unavailable")
  func couldNotDetermineWritesUnavailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: { .couldNotDetermine })

    await loader.load(into: syncStatus)

    #expect(syncStatus.accountStatus == .unavailable)
  }

  @Test("a throwing provider writes unavailable")
  func throwingProviderWritesUnavailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: {
      throw CKError(.networkUnavailable)
    })

    await loader.load(into: syncStatus)

    #expect(syncStatus.accountStatus == .unavailable)
  }

  /// Re-query after a sign-in: the notification-driven path transitions unavailable →
  /// available (the live chain `SettingsView.observeSingleNotification` drives on
  /// CKAccountChanged / NSUbiquityIdentityDidChange).
  @Test("reload after sign-in transitions to available")
  func reloadAfterSignInTransitionsToAvailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let signedIn = SignedInFlag()
    let loader = ICloudStatusLoader(accountStatus: {
      signedIn.value ? .available : .noAccount
    })

    await loader.load(into: syncStatus)
    #expect(syncStatus.accountStatus == .unavailable)

    signedIn.value = true
    await loader.load(into: syncStatus)
    #expect(syncStatus.accountStatus == .available)
    #expect(syncStatus.rowState == .available)
  }

  /// A query whose task has been superseded must not publish its answer.
  ///
  /// Settings cancels the in-flight status task and starts a new one whenever it reappears, and
  /// cancellation is cooperative — the old `CKContainer` query keeps running and resolves later. If
  /// it were allowed to write, a stale verdict would overwrite the fresher one and leave the row
  /// showing the wrong iCloud state until the next account-change notification.
  @Test("a cancelled load does not overwrite a fresher status")
  func cancelledLoadDoesNotOverwriteAFresherStatus() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    let loader = ICloudStatusLoader(accountStatus: { .noAccount })

    let task = Task { @MainActor in
      await loader.load(into: syncStatus)
    }
    // Cancelled before the body can run: the task is already cancelled when it starts.
    task.cancel()
    await task.value

    #expect(
      syncStatus.accountStatus == .available,
      "A cancelled query must leave the status alone rather than publishing a superseded answer."
    )
  }
}

/// Mutable flag the provider closure can capture (a closure can't capture an `inout`/`var` test
/// local across an `await` boundary).
private final class SignedInFlag {
  var value = false
}
