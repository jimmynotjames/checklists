//
//  RemoteChangeObserverTests.swift
//  checklistsTests
//

@testable import checklists
import CoreData
import XCTest

/// Covers `RemoteChangeObserver`'s coalescing: a burst of `NSPersistentStoreRemoteChange`
/// notifications — the shape a CloudKit merge actually produces — collapses into one callback.
///
/// See the doc comment on `DataModelTests` for why this class is `nonisolated` at the type level
/// with individual `@MainActor` test methods.
nonisolated final class RemoteChangeObserverTests: XCTestCase {
  @MainActor func testPostingNotificationCallsOnChangeOnce() {
    let callbackExpectation = expectation(description: "coalesced callback fired")
    var callCount = 0

    // Held for the duration of the test: `RemoteChangeObserver` unregisters its notification
    // observer on deallocation, so an observer that goes out of scope early would silently stop
    // seeing the notifications posted below.
    let observer = RemoteChangeObserver(coalescingDelay: .milliseconds(50)) {
      callCount += 1
      callbackExpectation.fulfill()
    }

    for _ in 0 ..< 3 {
      NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
    }

    wait(for: [callbackExpectation], timeout: 2.0)
    XCTAssertEqual(callCount, 1)

    withExtendedLifetime(observer) {}
  }
}
