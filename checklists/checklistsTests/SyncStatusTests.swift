//
//  SyncStatusTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// Covers `SyncStatus.rowState`'s derivation from `(containerBacking, accountStatus)`. No
/// container needed — `SyncStatus` is constructed directly and its properties mutated.
///
/// See the doc comment on `DataModelTests` for why this is `nonisolated final class ... :
/// XCTestCase` with `@MainActor` on each test method.
nonisolated final class SyncStatusTests: XCTestCase {
  @MainActor func testRowStateChecking() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .checking)
    XCTAssertEqual(syncStatus.rowState, .checking)
  }

  @MainActor func testRowStateAvailable() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .available)
    XCTAssertEqual(syncStatus.rowState, .available)
  }

  @MainActor func testRowStateUnavailable() {
    let syncStatus = SyncStatus(containerBacking: .cloudKit, accountStatus: .unavailable)
    XCTAssertEqual(syncStatus.rowState, .unavailable)
  }

  @MainActor func testRowStatePausedWhenLocalFallbackAndAvailable() {
    let syncStatus = SyncStatus(containerBacking: .localFallback, accountStatus: .available)
    XCTAssertEqual(syncStatus.rowState, .paused)
  }

  @MainActor func testRowStateUnavailableWhenLocalFallbackAndUnavailable() {
    let syncStatus = SyncStatus(containerBacking: .localFallback, accountStatus: .unavailable)
    XCTAssertEqual(syncStatus.rowState, .unavailable)
  }
}
