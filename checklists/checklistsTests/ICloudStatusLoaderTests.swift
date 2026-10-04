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
/// Ported from `simple-recurring-budgets`'s `ICloudStatusLoaderTests` suite of the same name.
@Suite("ICloudStatusLoader account status mapping")
struct ICloudStatusLoaderTests {
  @Test("every CKAccountStatus case maps to its own AccountStatus", arguments: [
    (CKAccountStatus.available, SyncStatus.AccountStatus.available),
    (.noAccount, .noAccount),
    (.restricted, .restricted),
    (.temporarilyUnavailable, .temporarilyUnavailable),
    (.couldNotDetermine, .couldNotDetermine),
  ])
  func everyAccountStatusCaseMaps(
    ckStatus: CKAccountStatus,
    expected: SyncStatus.AccountStatus
  ) async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: { ckStatus })

    await loader.load(into: syncStatus)

    #expect(syncStatus.accountStatus == expected)
  }

  @Test("a throwing provider writes couldNotDetermine")
  func throwingProviderWritesCouldNotDetermine() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: {
      throw CKError(.networkUnavailable)
    })

    await loader.load(into: syncStatus)

    #expect(syncStatus.accountStatus == .couldNotDetermine)
  }

  /// Re-query after a sign-in: the notification-driven path transitions could-not-determine →
  /// available (the live chain `ChecklistsApp`'s account-change observer drives on
  /// CKAccountChanged / NSUbiquityIdentityDidChange).
  @Test("reload after sign-in transitions to available")
  func reloadAfterSignInTransitionsToAvailable() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let signedIn = SignedInFlag()
    let loader = ICloudStatusLoader(accountStatus: {
      signedIn.value ? .available : .noAccount
    })

    await loader.load(into: syncStatus)
    #expect(syncStatus.accountStatus == .noAccount)

    signedIn.value = true
    await loader.load(into: syncStatus)
    #expect(syncStatus.accountStatus == .available)
    #expect(syncStatus.rowState == .available)
  }

  /// A load whose task is cancelled (its `.task` torn down) must not publish, even as the newest
  /// query: cancellation is cooperative, so the `CKContainer` query keeps running and resolves late.
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

  /// The launch check and the account-change observers run their loads concurrently, so the
  /// earlier-started query can resolve last.
  @Test("an earlier query that resolves last does not overwrite a later one", .timeLimit(.minutes(1)))
  func earlierQueryResolvingLastIsDropped() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let earlierAnswer = PendingAccountStatus()
    let earlier = Task {
      await ICloudStatusLoader(accountStatus: { await earlierAnswer.value() }).load(into: syncStatus)
    }
    await earlierAnswer.waitUntilRequested()

    await ICloudStatusLoader(accountStatus: { .available }).load(into: syncStatus)
    earlierAnswer.resolve(.noAccount)
    await earlier.value

    #expect(syncStatus.accountStatus == .available)
  }

  @Test("an earlier query still publishes while a later one is pending", .timeLimit(.minutes(1)))
  func earlierQueryPublishesWhileLaterIsPending() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let earlierAnswer = PendingAccountStatus()
    let laterAnswer = PendingAccountStatus()
    let earlier = Task {
      await ICloudStatusLoader(accountStatus: { await earlierAnswer.value() }).load(into: syncStatus)
    }
    await earlierAnswer.waitUntilRequested()
    let later = Task {
      await ICloudStatusLoader(accountStatus: { await laterAnswer.value() }).load(into: syncStatus)
    }
    await laterAnswer.waitUntilRequested()

    earlierAnswer.resolve(.noAccount)
    await earlier.value
    #expect(syncStatus.accountStatus == .noAccount)

    laterAnswer.resolve(.available)
    await later.value
    #expect(syncStatus.accountStatus == .available)
  }

  // MARK: - icloud_status_checked

  @Test("the first resolution off .checking fires icloud_status_checked once")
  func firstResolutionFiresIcloudStatusCheckedOnce() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let loader = ICloudStatusLoader(accountStatus: { .available })
    let spy = SpyAnalyticsClient()

    await loader.load(into: syncStatus, analytics: spy)

    #expect(spy.trackedEventNames == [AnalyticsEvent.icloudStatusChecked])
    #expect(spy.rawProperty(AnalyticsProperty.containerBacking, forFirst: AnalyticsEvent.icloudStatusChecked, as: String.self) == "cloudkit")
    #expect(spy.rawProperty(AnalyticsProperty.icloudAccount, forFirst: AnalyticsEvent.icloudStatusChecked, as: String.self) == "available")
  }

  @Test("a later re-query does not re-fire icloud_status_checked")
  func laterRequeryDoesNotRefire() async {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    let signedIn = SignedInFlag()
    let loader = ICloudStatusLoader(accountStatus: { signedIn.value ? .available : .noAccount })
    let spy = SpyAnalyticsClient()

    await loader.load(into: syncStatus, analytics: spy)
    signedIn.value = true
    await loader.load(into: syncStatus, analytics: spy)

    #expect(spy.count(of: AnalyticsEvent.icloudStatusChecked) == 1)
  }
}

/// Mutable flag the provider closure can capture (a closure can't capture an `inout`/`var` test
/// local across an `await` boundary).
private final class SignedInFlag {
  var value = false
}

/// An account-status answer the test releases by hand, to control which concurrent load resolves
/// first.
private final class PendingAccountStatus {
  private var continuation: CheckedContinuation<CKAccountStatus, Never>?

  func value() async -> CKAccountStatus {
    await withCheckedContinuation { continuation = $0 }
  }

  /// Returns once a load is suspended in `value()`, so the test knows its query number is taken.
  func waitUntilRequested() async {
    while continuation == nil {
      await Task.yield()
    }
  }

  func resolve(_ status: CKAccountStatus) {
    continuation?.resume(returning: status)
    continuation = nil
  }
}
