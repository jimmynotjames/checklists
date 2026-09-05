//
//  DataModelTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import XCTest

/**
 Covers the `@Model` types themselves — persistence round-trips, `percentageComplete`, and the
 cascade delete rule between `Checklist` and `Item`.

 ## Why `nonisolated final class ... : XCTestCase` with `@MainActor` on each test method

 The app target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and `checklistsTests` mirrors
 that setting. Left alone, that default would make every type declared in this target — including
 `XCTestCase` subclasses — implicitly main-actor isolated. That collides with `XCTestCase` itself:
 its designated initializers (`init()`, `init(selector:)`, `init(invocation:)`) and its
 `setUpWithError()`/`tearDownWithError()` overrides are all `nonisolated`, declared by a
 non-isolated Objective-C base class. A subclass cannot silently widen a nonisolated override to
 main-actor isolation, so the compiler rejects it with "Main actor-isolated instance method
 'setUpWithError()' has different actor isolation from nonisolated overridden declaration".

 `init(invocation:)` in particular cannot be fixed by adding `@MainActor` to it directly, because
 `NSInvocation` is unavailable in Swift on this platform — there is no way to write the override at
 all, isolated or not.

 The fix is the pattern used throughout this test target: declare the class itself `nonisolated`
 (opting the type back out of the target's default isolation, so it satisfies `XCTestCase`'s own
 nonisolated contract), then mark each individual test method — and any private helper that touches
 `@Model` types, `ModelContext`, or UIKit — `@MainActor`, since the persistence and UI code under
 test really is main-actor isolated. XCTest always invokes `setUp`, every test method, and `tearDown`
 on the main thread for a given instance, so hopping onto `@MainActor` inside each method is free at
 runtime; it exists purely to satisfy the type checker.

 (Originally documented on `LegacyRealmImporterTests`, before the Realm-based test files this class
 replaces existed; moved here as the canonical explanation once this class became the natural home
 for it. See `LegacyRealmImporterTests` for a worked example that also swaps a real Realm
 configuration into `setUp`/`tearDown`.)
 */
nonisolated final class DataModelTests: XCTestCase {
  @MainActor private func makeContext() throws -> ModelContext {
    try ModelContext(TestModelContainer.make())
  }

  @MainActor func testChecklistPersistsAndFetches() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Groceries", notes: "Weekly", sortKey: 1.0)
    context.insert(checklist)
    try context.saveChanges(operation: .checklistEdit)

    let fetched = try context.fetchChecklistsSorted()
    XCTAssertEqual(fetched.count, 1)
    XCTAssertEqual(fetched.first?.id, checklist.id)
    XCTAssertEqual(fetched.first?.name, "Groceries")
    XCTAssertEqual(fetched.first?.notes, "Weekly")
    XCTAssertEqual(fetched.first?.sortKey, 1.0)
  }

  @MainActor func testItemPersistsWithStatus() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Packing", sortKey: 1.0)
    context.insert(checklist)
    let item = Item(name: "Passport", notes: "in the drawer", sortKey: 1.0)
    item.status = .checked
    context.insert(item)
    item.checklist = checklist
    try context.saveChanges(operation: .itemEdit)

    let fetchedItem = try XCTUnwrap(context.item(id: item.id))
    XCTAssertEqual(fetchedItem.name, "Passport")
    XCTAssertEqual(fetchedItem.notes, "in the drawer")
    XCTAssertEqual(fetchedItem.status, .checked)
    XCTAssertEqual(fetchedItem.checklist?.id, checklist.id)
  }

  @MainActor func testPercentageCompleteEmptyIsZero() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Empty", sortKey: 1.0)
    context.insert(checklist)
    try context.saveChanges(operation: .checklistEdit)

    XCTAssertEqual(checklist.percentageComplete, 0.0)
  }

  @MainActor func testPercentageCompleteHalf() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Half", sortKey: 1.0)
    context.insert(checklist)

    let checkedItem = Item(name: "Done", sortKey: 1.0)
    checkedItem.status = .checked
    context.insert(checkedItem)
    checkedItem.checklist = checklist

    let uncheckedItem = Item(name: "Not done", sortKey: 2.0)
    context.insert(uncheckedItem)
    uncheckedItem.checklist = checklist

    try context.saveChanges(operation: .itemEdit)

    XCTAssertEqual(checklist.percentageComplete, 0.5, accuracy: 0.0001)
  }

  @MainActor func testDeletingChecklistCascadesItems() throws {
    let context = try makeContext()
    let checklist = Checklist(name: "Doomed", sortKey: 1.0)
    context.insert(checklist)

    let itemOne = Item(name: "one", sortKey: 1.0)
    context.insert(itemOne)
    itemOne.checklist = checklist

    let itemTwo = Item(name: "two", sortKey: 2.0)
    context.insert(itemTwo)
    itemTwo.checklist = checklist

    try context.saveChanges(operation: .checklistEdit)
    XCTAssertEqual(try context.fetch(FetchDescriptor<Item>()).count, 2)

    context.delete(checklist)
    try context.saveChanges(operation: .delete)

    XCTAssertTrue(try context.fetch(FetchDescriptor<Item>()).isEmpty)
  }
}
