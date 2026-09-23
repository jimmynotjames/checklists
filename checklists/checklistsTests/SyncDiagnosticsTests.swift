//
//  SyncDiagnosticsTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing

/// `SyncDiagnostics.report` is pure, so every `SyncStatus` shape is covered directly — no
/// container, no Feedback email.
@Suite("SyncDiagnostics.report")
struct SyncDiagnosticsTests {
  @Test("every account status appears in the report", arguments: SyncStatus.AccountStatus.allCases)
  func everyAccountStatusAppears(accountStatus: SyncStatus.AccountStatus) {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: accountStatus)
    let report = SyncDiagnostics.report(syncStatus: syncStatus, appVersion: "1.3", build: "45", osVersion: "26.1")
    #expect(report.contains("iCloud account: \(accountStatus.rawValue)"))
  }

  @Test("the report names the container backing and app/OS versions")
  func reportNamesBackingAndVersions() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    let report = SyncDiagnostics.report(syncStatus: syncStatus, appVersion: "1.3", build: "45", osVersion: "26.1")
    #expect(report.contains("Store: cloudkit"))
    #expect(report.contains("App 1.3 (45) · iOS 26.1"))
  }

  @Test("no fallback error reports none")
  func noFallbackErrorReportsNone() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    let report = SyncDiagnostics.report(syncStatus: syncStatus, appVersion: "1.3", build: "45", osVersion: "26.1")
    #expect(report.contains("Launch fallback: none"))
  }

  @Test("a fallback error reports its domain and code")
  func fallbackErrorReportsDomainAndCode() {
    let syncStatus = SyncStatus(
      containerBacking: .localFallback,
      accountStatus: .available,
      fallbackError: SyncErrorCode(domain: "NSCocoaErrorDomain", code: 134_060)
    )
    let report = SyncDiagnostics.report(syncStatus: syncStatus, appVersion: "1.3", build: "45", osVersion: "26.1")
    #expect(report.contains("Launch fallback: NSCocoaErrorDomain 134060"))
  }

  @Test("an operation with no recorded activity reports no activity")
  func operationWithNoActivityReportsNoActivity() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    let report = SyncDiagnostics.report(syncStatus: syncStatus, appVersion: "1.3", build: "45", osVersion: "26.1")
    #expect(report.contains("setup: no activity"))
    #expect(report.contains("import: no activity"))
    #expect(report.contains("export: no activity"))
  }

  @Test("a successful operation reports ok and its date")
  func successfulOperationReportsOk() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    syncStatus.record(SyncEventSnapshot(operation: .setup, endDate: Date(timeIntervalSince1970: 0), error: nil))
    let report = SyncDiagnostics.report(syncStatus: syncStatus, appVersion: "1.3", build: "45", osVersion: "26.1")
    #expect(report.contains("setup: ok 1970-01-01T00:00:00Z"))
  }

  @Test("a failed operation with a prior success reports both")
  func failedOperationWithPriorSuccessReportsBoth() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    syncStatus.record(SyncEventSnapshot(operation: .export, endDate: Date(timeIntervalSince1970: 0), error: nil))
    syncStatus.record(SyncEventSnapshot(
      operation: .export,
      endDate: Date(timeIntervalSince1970: 100),
      error: SyncErrorCode(domain: "CKErrorDomain", code: 25)
    ))
    let report = SyncDiagnostics.report(syncStatus: syncStatus, appVersion: "1.3", build: "45", osVersion: "26.1")
    #expect(report.contains("export: failed CKErrorDomain 25 (last ok 1970-01-01T00:00:00Z)"))
  }

  @Test("a failed operation with no prior success says so")
  func failedOperationWithNoPriorSuccessSaysSo() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    syncStatus.record(SyncEventSnapshot(
      operation: .import,
      endDate: Date(timeIntervalSince1970: 0),
      error: SyncErrorCode(domain: "CKErrorDomain", code: 2)
    ))
    let report = SyncDiagnostics.report(syncStatus: syncStatus, appVersion: "1.3", build: "45", osVersion: "26.1")
    #expect(report.contains("import: failed CKErrorDomain 2 (no prior success)"))
  }
}
