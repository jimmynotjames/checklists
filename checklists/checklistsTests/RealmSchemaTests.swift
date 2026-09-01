//
//  RealmSchemaTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import RealmSwift
import UniformTypeIdentifiers
import XCTest

/// Covers the ordering/mutation methods on `Group`, `Checklist`, and `Item` in `RealmSchema.swift`
/// that aren't exercised by `DataModelTests`.
///
/// See the note on `DataModelTests` for why this class is `nonisolated` at the type level with
/// individual `@MainActor` test methods, rather than relying on the target's default actor
/// isolation on the class itself.
///
/// Uses an in-memory Realm swapped into `DBManager.realm` for the duration of each test (see
/// setUp/tearDown below) rather than the persisted store `DataModelTests` deliberately uses — the
/// save/restore is mandatory since XCTest runs all classes in one process and `DataModelTests`
/// must keep seeing the persisted store regardless of run order.
/// `@unchecked Sendable`: `MainActor.assumeIsolated` (used in setUp/tearDown below) captures `self`
/// to reach `previousRealm`, and the compiler can't verify that crossing is safe on its own since
/// this class isn't Sendable by default. It genuinely is safe here — XCTest always invokes setUp,
/// every test method, and tearDown on the main thread, serially, for a given instance — so this is
/// the same kind of test-only escape hatch as the class-level `nonisolated` above.
nonisolated final class RealmSchemaTests: XCTestCase, @unchecked Sendable {
  private var previousRealm: Realm!

  override func setUpWithError() throws {
    try MainActor.assumeIsolated {
      previousRealm = DBManager.realm
      DBManager.realm = try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "RealmSchemaTests-\(UUID().uuidString)"))
    }
  }

  override func tearDownWithError() throws {
    MainActor.assumeIsolated {
      DBManager.realm = previousRealm
    }
  }

  // MARK: - Group.moveChecklist(from:to:)

  @MainActor func testGroupMoveChecklistForward() {
    let group = Group()
    let checklists = ["A", "B", "C", "D"].map { Checklist(name: $0, items: []) }
    group.checklists.append(objectsIn: checklists)
    DBManager.write { DBManager.realm.add(group) }

    group.moveChecklist(from: 1, to: 3) // [A, C, D, B]

    XCTAssertEqual(group.checklists.map(\.name), ["A", "C", "D", "B"])
  }

  @MainActor func testGroupMoveChecklistBackward() {
    let group = Group()
    let checklists = ["A", "B", "C", "D"].map { Checklist(name: $0, items: []) }
    group.checklists.append(objectsIn: checklists)
    DBManager.write { DBManager.realm.add(group) }

    group.moveChecklist(from: 3, to: 0) // [D, A, B, C]

    XCTAssertEqual(group.checklists.map(\.name), ["D", "A", "B", "C"])
  }

  @MainActor func testGroupMoveChecklistFirstToLastBoundary() {
    let group = Group()
    let checklists = ["A", "B", "C"].map { Checklist(name: $0, items: []) }
    group.checklists.append(objectsIn: checklists)
    DBManager.write { DBManager.realm.add(group) }

    group.moveChecklist(from: 0, to: group.checklists.count - 1) // [B, C, A]

    XCTAssertEqual(group.checklists.map(\.name), ["B", "C", "A"])
  }

  // MARK: - Checklist.remove(at:)

  @MainActor func testChecklistRemoveAt() {
    let items = ["one", "two", "three"].map { Item(name: $0) }
    let checklist = Checklist(name: "Test", items: items)
    DBManager.write { DBManager.realm.add(checklist) }

    checklist.remove(at: 1)

    XCTAssertEqual(checklist.items.map(\.name), ["one", "three"])
    // The removed item should also have been deleted from the realm, not merely unlinked.
    XCTAssertEqual(DBManager.realm.objects(Item.self).count(where: { $0.name == "two" }), 0)
  }

  // MARK: - Checklist.moveItem(from:to:)

  @MainActor func testChecklistMoveItem() {
    let items = ["one", "two", "three", "four"].map { Item(name: $0) }
    let checklist = Checklist(name: "Test", items: items)
    DBManager.write { DBManager.realm.add(checklist) }

    checklist.moveItem(from: 0, to: 3) // [two, three, four, one]

    XCTAssertEqual(checklist.items.map(\.name), ["two", "three", "four", "one"])
  }

  // MARK: - Checklist.swapItemsAt(_:_:)

  @MainActor func testChecklistSwapItemsAt() {
    let items = ["one", "two", "three"].map { Item(name: $0) }
    let checklist = Checklist(name: "Test", items: items)
    DBManager.write { DBManager.realm.add(checklist) }

    checklist.swapItemsAt(0, 2)

    XCTAssertEqual(checklist.items.map(\.name), ["three", "two", "one"])
  }

  // MARK: - Checklist.uncheckAllItems()

  @MainActor func testUncheckAllItemsWithMixedStatuses() {
    let items = ["one", "two", "three"].map { Item(name: $0) }
    let checklist = Checklist(name: "Test", items: items)
    DBManager.write { DBManager.realm.add(checklist) }
    DBManager.write {
      items[0].status = .checked
      items[2].status = .checked
    }
    XCTAssertEqual(checklist.percentageComplete, 2.0 / 3.0, accuracy: 0.0001)

    checklist.uncheckAllItems()

    XCTAssertTrue(checklist.items.allSatisfy { $0.status == .unchecked })
  }

  @MainActor func testUncheckAllItemsOnEmptyChecklist() {
    let checklist = Checklist(name: "Test", items: [])
    DBManager.write { DBManager.realm.add(checklist) }

    checklist.uncheckAllItems() // Should not crash on an empty list.

    XCTAssertTrue(checklist.items.isEmpty)
  }

  // MARK: - Item.toggleStatus() / Item.status

  @MainActor func testItemToggleStatusRoundTrip() {
    let item = Item(name: "Test")
    XCTAssertEqual(item.status, .unchecked)

    item.toggleStatus()
    XCTAssertEqual(item.status, .checked)

    item.toggleStatus()
    XCTAssertEqual(item.status, .unchecked)
  }

  @MainActor func testItemStatusSetterGetter() {
    let item = Item(name: "Test")

    item.status = .checked
    XCTAssertEqual(item.status, .checked)
    XCTAssertEqual(item.statusRaw, Item.Status.checked.rawValue)

    item.status = .unchecked
    XCTAssertEqual(item.status, .unchecked)
    XCTAssertEqual(item.statusRaw, Item.Status.unchecked.rawValue)
  }

  /// `statusRaw` is the persisted `Int`; `status` falls back to `.defaultValue` for any raw value
  /// that doesn't map to a known case (e.g. corrupted or from a future app version this one
  /// doesn't understand).
  @MainActor func testItemStatusFallsBackOnCorruptRawValue() {
    let item = Item(name: "Test")
    DBManager.write { DBManager.realm.add(item) }

    DBManager.write { item.statusRaw = 99 }

    XCTAssertEqual(item.status, Item.Status.defaultValue)
  }

  // MARK: - dragItems() NSItemProvider round trip

  @MainActor func testChecklistDragItemsRoundTripsId() throws {
    let checklist = Checklist(name: "Test", items: [])
    DBManager.write { DBManager.realm.add(checklist) }

    let dragItems = checklist.dragItems()
    XCTAssertEqual(dragItems.count, 1)

    let payload = try loadPlainTextPayload(from: dragItems[0].itemProvider)
    XCTAssertEqual(payload, checklist.id)
  }

  @MainActor func testItemDragItemsRoundTripsId() throws {
    let item = Item(name: "Test")
    DBManager.write { DBManager.realm.add(item) }

    let dragItems = item.dragItems()
    XCTAssertEqual(dragItems.count, 1)

    let payload = try loadPlainTextPayload(from: dragItems[0].itemProvider)
    XCTAssertEqual(payload, item.id)
  }

  /// Drives the async `NSItemProvider` data-representation callback registered by `dragItems()`
  /// and decodes the resulting UTF-8 payload synchronously for the test.
  private func loadPlainTextPayload(from itemProvider: NSItemProvider) throws -> String {
    let expectation = expectation(description: "plain text data representation loaded")
    var result: Result<String, Error> = .failure(placeholderError)

    itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.plainText.identifier) { data, error in
      if let error {
        result = .failure(error)
      } else if let data, let string = String(data: data, encoding: .utf8) {
        result = .success(string)
      } else {
        result = .failure(placeholderError)
      }
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5)
    return try result.get()
  }
}

/// Placeholder `Error` used only to seed `Result`'s initial value before the async callback in
/// `loadPlainTextPayload(from:)` runs; never surfaced to a passing test. `nonisolated` because
/// it's read from that callback, which the system can invoke off the main actor.
nonisolated private let placeholderError = NSError(domain: "RealmSchemaTests", code: -1)
