//
//  DataModelTests.swift
//  checklistsTests
//
//  Created by Jimmy Ho on 12/6/20.
//

@testable import checklists
import RealmSwift
import XCTest

private let checklistName = "Test Checklist 1"
private let checklistNotes = "Some notes about Checklist1; blah blah blah...\nMore blah blah blah\nAnd more with emojis: 🤪🧐🤷🏼‍♀️"

private let itemName1 = "Masquerade mask"
private let itemNotes1 = "Match to final choice of shoes"
private let itemName2 = "Contact lenses"
private let itemName3 = "flip flops"
private let itemName4 = "tiara"
private let itemNotes4 = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
  + "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. "
  + "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. "
  + "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

/// WARNING: Running these tests will reset the app's database on whatever simulator this is run on.
///
/// This class (and every `XCTestCase` subclass added under Phase 4/5) is deliberately left
/// `nonisolated` at the type level, matching `XCTestCase` itself. `SWIFT_DEFAULT_ACTOR_ISOLATION
/// = MainActor` on this target would otherwise make the class MainActor-isolated by default,
/// which conflicts with `XCTestCase`'s own nonisolated designated initializers — including
/// `init(invocation:)`, whose `NSInvocation` parameter type is unavailable in Swift on this
/// platform, so that particular conflict cannot be resolved with an explicit override. Individual
/// test methods are marked `@MainActor` instead, since they (transitively, via `DBManager` and the
/// Realm model types) need it; `setUpWithError`/`tearDownWithError` stay nonisolated to match the
/// superclass and hop onto the main actor internally with `MainActor.assumeIsolated`, which is
/// sound because XCTest always invokes them on the main thread.
nonisolated final class DataModelTests: XCTestCase {
  override func setUpWithError() throws {
    // We're going to test with persisted store, not memory store, against recommendation, because I want to make sure the file stuff is okay.
    MainActor.assumeIsolated {
      DBManager.write {
        DBManager.realm.deleteAll()
      }
    }
  }

  override func tearDownWithError() throws {
    MainActor.assumeIsolated {
      DBManager.write {
        DBManager.realm.deleteAll()
      }
    }
  }

  @MainActor func testCreateEmptyChecklist1() {
    let checklist = Checklist(name: "Test Checklist 1", items: [])
    let expected = snapshot(of: checklist)

    DBManager.write {
      DBManager.realm.add(checklist)
    }
    guard let retrievedChecklist = DBManager.realm.objects(Checklist.self).first(where: { $0.id == expected.id })
    else { XCTFail("Checklist was not persisted"); return }

    assertChecklist(retrievedChecklist, matches: expected)
  }

  @MainActor func testCreateChecklist2() {
    let checklist = Checklist(name: checklistName, notes: checklistNotes, sortNumber: nil, items: [])
    let expected = snapshot(of: checklist)

    DBManager.write {
      DBManager.realm.add(checklist)
    }
    guard let retrievedChecklist = DBManager.realm.objects(Checklist.self).first(where: { $0.id == expected.id })
    else { XCTFail("Checklist was not persisted"); return }

    assertChecklist(retrievedChecklist, matches: expected)
  }

  @MainActor func testCreateChecklistWithItems() {
    let items: [Item] = [Item(name: itemName1, notes: itemNotes1), Item(name: itemName2), Item(name: itemName3), Item(name: itemName4, notes: itemNotes4)]
    items[1].toggleStatus()
    items[3].toggleStatus()
    let checklist = Checklist(name: checklistName, notes: checklistNotes, sortNumber: nil, items: items)
    let expected = snapshot(of: checklist)

    DBManager.write {
      DBManager.realm.add(checklist)
    }
    guard let retrievedChecklist = DBManager.realm.objects(Checklist.self).first(where: { $0.id == expected.id })
    else { XCTFail("Checklist was not persisted"); return }

    assertChecklist(retrievedChecklist, matches: expected)
  }

  @MainActor func testChecklistPercentComplete() {
    let items: [Item] = [Item(name: itemName1, notes: itemNotes1), Item(name: itemName2), Item(name: itemName3), Item(name: itemName4, notes: itemNotes4)]
    items[1].toggleStatus()
    items[3].toggleStatus()
    let checklist = Checklist(name: checklistName, notes: checklistNotes, sortNumber: nil, items: items)

    XCTAssertEqual(checklist.percentageComplete, 0.50)
    items[1].toggleStatus()
    XCTAssertEqual(checklist.percentageComplete, 0.25)
    items[3].toggleStatus()
    XCTAssertEqual(checklist.percentageComplete, 0.0)
    checklist.items.removeAll() // Test empty case (can cause divide-by-zero)
    XCTAssertEqual(checklist.percentageComplete, 0.0)
  }

  /// Plain-value snapshot of an `Item`, taken while it's still unmanaged, so later assertions
  /// compare the persisted-and-refetched object against independent data rather than against
  /// itself (Realm's `add()` promotes the passed-in object to managed in place, so comparing a
  /// refetched object back against the same instance you just added is tautological).
  private struct ExpectedItem {
    let id: String
    let name: String
    let notes: String?
    let status: Item.Status
  }

  /// Plain-value snapshot of a `Checklist`; see `ExpectedItem`.
  private struct ExpectedChecklist {
    let id: String
    let name: String
    let notes: String?
    let sortNumber: Double
    let lastModified: Date
    let items: [ExpectedItem]
  }

  @MainActor private func snapshot(of checklist: Checklist) -> ExpectedChecklist {
    ExpectedChecklist(
      id: checklist.id,
      name: checklist.name,
      notes: checklist.notes,
      sortNumber: checklist.sortNumber,
      lastModified: checklist.lastModified,
      items: checklist.items.map { ExpectedItem(id: $0.id, name: $0.name, notes: $0.notes, status: $0.status) }
    )
  }

  @MainActor private func assertChecklist(_ checklist: Checklist, matches expected: ExpectedChecklist) {
    XCTAssertEqual(checklist.id, expected.id)
    XCTAssertEqual(checklist.name, expected.name)
    XCTAssertEqual(checklist.notes, expected.notes)
    XCTAssertEqual(checklist.sortNumber, expected.sortNumber)
    XCTAssertEqual(checklist.lastModified, expected.lastModified)
    XCTAssertEqual(checklist.items.count, expected.items.count)

    for (item, expectedItem) in zip(checklist.items, expected.items) {
      XCTAssertEqual(item.id, expectedItem.id)
      XCTAssertEqual(item.name, expectedItem.name)
      XCTAssertEqual(item.notes, expectedItem.notes)
      XCTAssertEqual(item.status, expectedItem.status)
    }
  }
}
