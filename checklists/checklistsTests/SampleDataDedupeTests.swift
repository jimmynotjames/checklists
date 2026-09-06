//
//  SampleDataDedupeTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import XCTest

/**
 Covers `SampleData.dedupeChecklists(in:)`, the only code in the app that deletes records on its own
 initiative. The tests are therefore written around what it must *refuse* to delete as much as what
 it collapses.

 See the doc comment on `DataModelTests` for why this class is `nonisolated` at the type level with
 individual `@MainActor` test methods.
 */
nonisolated final class SampleDataDedupeTests: XCTestCase {
  @MainActor private func makeContext() throws -> ModelContext {
    try ModelContext(TestModelContainer.make())
  }

  /// Seeds the fixture a second time, reproducing what a second device uploads when it seeds before
  /// the first device's records have synced down.
  @MainActor private func seedSecondCopy(into context: ModelContext) throws {
    try SampleData.seed(into: context)
  }

  // MARK: - No-op cases

  @MainActor func testNoDuplicatesIsNoOp() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)

    try SampleData.dedupeChecklists(in: context)

    XCTAssertEqual(try context.fetchChecklistsSorted().count, 3)
  }

  @MainActor func testEmptyStoreIsNoOp() throws {
    let context = try makeContext()
    try SampleData.dedupeChecklists(in: context)
    XCTAssertTrue(try context.fetchChecklistsSorted().isEmpty)
  }

  // MARK: - The case it exists for

  @MainActor func testTwoPristineCopiesCollapseToOne() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)
    XCTAssertEqual(try context.fetchChecklistsSorted().count, 6)

    try SampleData.dedupeChecklists(in: context)

    let remaining = try context.fetchChecklistsSorted()
    XCTAssertEqual(remaining.count, 3)
    XCTAssertEqual(Set(remaining.map(\.name)), ["Morning Routine", "Weekend Getaway Essentials", "Pre-Trip Checklist"])
  }

  /// The survivor's items must come with it — a collapse that orphaned or dropped items would be
  /// worse than the duplication it fixes.
  @MainActor func testSurvivorKeepsItsItems() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    try SampleData.dedupeChecklists(in: context)

    let byName = try Dictionary(uniqueKeysWithValues: context.fetchChecklistsSorted().map { ($0.name, $0) })
    XCTAssertEqual(byName["Morning Routine"]?.items.count, 6)
    XCTAssertEqual(byName["Weekend Getaway Essentials"]?.items.count, 12)
    XCTAssertEqual(byName["Pre-Trip Checklist"]?.items.count, 11)
  }

  /// The discarded copy's items must not survive as orphans.
  @MainActor func testDiscardedCopyTakesItsItemsWithIt() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)
    XCTAssertEqual(try context.fetch(FetchDescriptor<Item>()).count, 58)

    try SampleData.dedupeChecklists(in: context)

    XCTAssertEqual(try context.fetch(FetchDescriptor<Item>()).count, 29)
    XCTAssertTrue(
      try context.fetch(FetchDescriptor<Item>()).allSatisfy { $0.checklist != nil },
      "Cascade delete must not leave orphaned items behind."
    )
  }

  /// Every device must elect the same survivor, or two devices deduping at once would delete one
  /// copy each and leave the user with none.
  @MainActor func testSurvivorElectionIsDeterministic() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    let morningRoutineCopies = try context.fetchChecklistsSorted().filter { $0.id == SampleData.morningRoutineId }
    let expectedSurvivorItemIds = morningRoutineCopies
      .map { $0.items.map(\.id).sorted().joined(separator: ",") }
      .min()

    try SampleData.dedupeChecklists(in: context)

    let survivor = try XCTUnwrap(try context.checklist(id: SampleData.morningRoutineId))
    XCTAssertEqual(
      survivor.items.map(\.id).sorted().joined(separator: ","),
      expectedSurvivorItemIds,
      "The survivor must be chosen by a rule every device computes identically."
    )
  }

  // MARK: - What it must refuse to touch

  @MainActor func testKeepsBothWhenAnItemWasRenamed() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    let edited = try XCTUnwrap(try context.fetchChecklistsSorted().first { $0.id == SampleData.morningRoutineId })
    edited.items.first?.name = "Start the coffee maker, but louder"
    try context.saveChanges(operation: .itemEdit)

    try SampleData.dedupeChecklists(in: context)

    let morningRoutines = try context.fetchChecklistsSorted().filter { $0.id == SampleData.morningRoutineId }
    XCTAssertEqual(morningRoutines.count, 2, "An edited copy is the user's data and must be kept.")
  }

  /// Checking a box is the most likely edit of all, and must be enough to protect a copy.
  @MainActor func testKeepsBothWhenCheckedStatesDiffer() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    let edited = try XCTUnwrap(try context.fetchChecklistsSorted().first { $0.id == SampleData.preTripId })
    edited.items.first?.status = .checked
    try context.saveChanges(operation: .itemEdit)

    try SampleData.dedupeChecklists(in: context)

    XCTAssertEqual(try context.fetchChecklistsSorted().count(where: { $0.id == SampleData.preTripId }), 2)
  }

  @MainActor func testKeepsBothWhenAnItemWasAdded() throws {
    let context = try makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    let edited = try XCTUnwrap(try context.fetchChecklistsSorted().first { $0.id == SampleData.preTripId })
    try context.insert(item: Item(name: "One more thing"), at: 0, in: edited)

    try SampleData.dedupeChecklists(in: context)

    XCTAssertEqual(try context.fetchChecklistsSorted().count(where: { $0.id == SampleData.preTripId }), 2)
  }

  /// Two checklists that merely look alike but carry different ids are ordinary user data, whatever
  /// their contents. This is the two-device upgrade case, and it must be left entirely alone.
  @MainActor func testNeverTouchesChecklistsWithDifferentIds() throws {
    let context = try makeContext()
    for _ in 0 ..< 2 {
      let checklist = Checklist(name: "Morning Routine", sortKey: 1.0)
      context.insert(checklist)
      try context.insert(item: Item(name: "START COFFEE MAKER"), at: 0, in: checklist)
    }
    try context.saveChanges(operation: .checklistEdit)

    try SampleData.dedupeChecklists(in: context)

    XCTAssertEqual(try context.fetchChecklistsSorted().count, 2, "Distinct ids are distinct records, however similar.")
  }
}
