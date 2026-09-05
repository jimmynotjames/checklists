//
//  SortKeyReorderTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// Covers `SortKeyReorder`'s pure arithmetic: midpoint insertion at the front, the end, and between
/// two neighbours; the `epsilon` floor that signals a caller must renormalize; and renormalization
/// itself.
///
/// `SortKeyReorder`'s members are all `nonisolated static`, so — unlike the rest of this target —
/// these test methods need no `@MainActor` annotation: there is no `@Model`, `ModelContext`, or
/// UIKit involved. See the doc comment on `DataModelTests` for why other classes in this target
/// need it.
nonisolated final class SortKeyReorderTests: XCTestCase {
  private final class Box {
    var value: Double = 0.0
  }

  func testInsertAtFrontHalvesFirstKey() {
    let key = SortKeyReorder.key(forInsertingAt: 0, in: [1.0, 2.0, 3.0])
    XCTAssertEqual(key, 0.5)
  }

  func testInsertAtEndAddsOne() {
    let key = SortKeyReorder.key(forInsertingAt: 3, in: [1.0, 2.0, 3.0])
    XCTAssertEqual(key, 4.0)
  }

  func testInsertBetweenUsesMidpoint() {
    let key = SortKeyReorder.key(forInsertingAt: 1, in: [1.0, 2.0])
    XCTAssertEqual(key, 1.5)
  }

  func testTinyGapReturnsNil() {
    let tinyGap = SortKeyReorder.epsilon / 2.0
    let key = SortKeyReorder.key(forInsertingAt: 1, in: [1.0, 1.0 + tinyGap])
    XCTAssertNil(key)
  }

  func testEmptyListReturnsStep() {
    let key = SortKeyReorder.key(forInsertingAt: 0, in: [])
    XCTAssertEqual(key, SortKeyReorder.step)
  }

  func testRenormalizeAssignsIntegers() {
    let boxes = [Box(), Box(), Box()]
    SortKeyReorder.renormalize(boxes) { box, key in box.value = key }
    XCTAssertEqual(boxes.map(\.value), [1.0, 2.0, 3.0])
  }
}
