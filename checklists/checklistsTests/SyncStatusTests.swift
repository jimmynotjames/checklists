//
//  SyncStatusTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// Covers `SyncStatus.rowState`'s derivation from `(containerBacking, accountStatus)`. No
/// container needed — `SyncStatus` is constructed directly and its properties mutated.
@Suite("SyncStatus.rowState")
struct SyncStatusTests {
  @Test("checking account status yields .checking")
  func rowStateChecking() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    #expect(syncStatus.rowState == .checking)
  }

  @Test("available on a CloudKit container yields .available")
  func rowStateAvailable() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    #expect(syncStatus.rowState == .available)
  }

  @Test("unavailable on a CloudKit container yields .unavailable")
  func rowStateUnavailable() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .unavailable)
    #expect(syncStatus.rowState == .unavailable)
  }

  @Test("local fallback with an available account yields .paused")
  func rowStatePausedWhenLocalFallbackAndAvailable() {
    let syncStatus = SyncStatus(containerBacking: .localFallback, accountStatus: .available)
    #expect(syncStatus.rowState == .paused)
  }

  @Test("local fallback with an unavailable account yields .unavailable")
  func rowStateUnavailableWhenLocalFallbackAndUnavailable() {
    let syncStatus = SyncStatus(containerBacking: .localFallback, accountStatus: .unavailable)
    #expect(syncStatus.rowState == .unavailable)
  }
}
