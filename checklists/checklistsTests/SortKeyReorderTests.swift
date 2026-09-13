//
//  SortKeyReorderTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// Covers `SortKeyReorder`'s pure arithmetic: midpoint insertion at the front, the end, and between
/// two neighbours; the `epsilon` floor that signals a caller must renormalize; and renormalization
/// itself.
@Suite("SortKeyReorder arithmetic")
struct SortKeyReorderTests {
  private final class Box {
    var value: Double = 0.0
  }

  @Test("inserting at the front halves the first key")
  func insertAtFrontHalvesFirstKey() {
    let key = SortKeyReorder.key(forInsertingAt: 0, in: [1.0, 2.0, 3.0])
    #expect(key == 0.5)
  }

  @Test("inserting at the end adds one to the last key")
  func insertAtEndAddsOne() {
    let key = SortKeyReorder.key(forInsertingAt: 3, in: [1.0, 2.0, 3.0])
    #expect(key == 4.0)
  }

  @Test("inserting between two neighbours uses their midpoint")
  func insertBetweenUsesMidpoint() {
    let key = SortKeyReorder.key(forInsertingAt: 1, in: [1.0, 2.0])
    #expect(key == 1.5)
  }

  @Test("a gap smaller than epsilon returns nil")
  func tinyGapReturnsNil() {
    let tinyGap = SortKeyReorder.epsilon / 2.0
    let key = SortKeyReorder.key(forInsertingAt: 1, in: [1.0, 1.0 + tinyGap])
    #expect(key == nil)
  }

  @Test("an empty list returns the step value")
  func emptyListReturnsStep() {
    let key = SortKeyReorder.key(forInsertingAt: 0, in: [])
    #expect(key == SortKeyReorder.step)
  }

  @Test("renormalizing assigns contiguous integer keys")
  func renormalizeAssignsIntegers() {
    let boxes = [Box(), Box(), Box()]
    SortKeyReorder.renormalize(boxes) { box, key in box.value = key }
    #expect(boxes.map(\.value) == [1.0, 2.0, 3.0])
  }
}
