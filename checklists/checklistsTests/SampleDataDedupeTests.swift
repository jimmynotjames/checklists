//
//  SampleDataDedupeTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import Synchronization
import Testing

/// Covers `SampleData.dedupeChecklists(in:)`, the only code in the app that deletes records on its own
/// initiative. The tests are therefore written around what it must *refuse* to delete as much as what
/// it collapses.
@Suite("SampleData deduplication")
struct SampleDataDedupeTests {
  /// Seeds the fixture a second time, reproducing a fresh install (a reinstall, or a second device)
  /// seeding before the account's existing records have synced down.
  private func seedSecondCopy(into context: ModelContext) throws {
    try SampleData.seed(into: context)
  }

  // MARK: - No-op cases

  @Test("deduping a store with no duplicates is a no-op")
  func noDuplicatesIsNoOp() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)

    try SampleData.dedupeChecklists(in: context)

    #expect(try context.fetchChecklistsSorted().count == 3)
  }

  @Test("deduping an empty store is a no-op")
  func emptyStoreIsNoOp() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.dedupeChecklists(in: context)
    #expect(try context.fetchChecklistsSorted().isEmpty)
  }

  // MARK: - The case it exists for

  @Test("two pristine copies collapse to one")
  func twoPristineCopiesCollapseToOne() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)
    #expect(try context.fetchChecklistsSorted().count == 6)

    try SampleData.dedupeChecklists(in: context)

    let remaining = try context.fetchChecklistsSorted()
    #expect(remaining.count == 3)
    #expect(Set(remaining.map(\.name)) == ["Morning Routine", "Weekend Getaway Essentials", "Pre-Trip Checklist"])
  }

  /// The survivor's items must come with it — a collapse that orphaned or dropped items would be
  /// worse than the duplication it fixes.
  @Test("the surviving copy keeps its items")
  func survivorKeepsItsItems() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    try SampleData.dedupeChecklists(in: context)

    let byName = try Dictionary(uniqueKeysWithValues: context.fetchChecklistsSorted().map { ($0.name, $0) })
    #expect(byName["Morning Routine"]?.items.count == 6)
    #expect(byName["Weekend Getaway Essentials"]?.items.count == 12)
    #expect(byName["Pre-Trip Checklist"]?.items.count == 11)
  }

  /// The discarded copy's items must not survive as orphans.
  @Test("the discarded copy's items are deleted with it")
  func discardedCopyTakesItsItemsWithIt() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)
    #expect(try context.fetch(FetchDescriptor<Item>()).count == 58)

    try SampleData.dedupeChecklists(in: context)

    #expect(try context.fetch(FetchDescriptor<Item>()).count == 29)
    #expect(
      try context.fetch(FetchDescriptor<Item>()).allSatisfy { $0.checklist != nil },
      "Cascade delete must not leave orphaned items behind.",
    )
  }

  /// Dedupe's deletions are local saves, which raise no remote-change notification; an open screen
  /// showing a deleted copy hears about it only through this one. A no-op pass must stay silent, or
  /// the list's observer, which runs dedupe on it, would loop.
  @Test("posts didRemoveDuplicates only when it deleted something")
  func postsOnlyWhenItDeleted() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    let posts = Mutex(0)
    let token = NotificationCenter.default.addObserver(forName: SampleData.didRemoveDuplicates, object: nil, queue: nil) { _ in
      posts.withLock { $0 += 1 }
    }
    defer { NotificationCenter.default.removeObserver(token) }

    try SampleData.dedupeChecklists(in: context)
    #expect(posts.withLock { $0 } == 0)

    try seedSecondCopy(into: context)
    try SampleData.dedupeChecklists(in: context)
    #expect(posts.withLock { $0 } == 1)
  }

  /// Every device must elect the same survivor, or two devices deduping at once would delete one
  /// copy each and leave the user with none.
  @Test("survivor election is deterministic")
  func survivorElectionIsDeterministic() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    let morningRoutineCopies = try context.fetchChecklistsSorted().filter { $0.id == SampleData.morningRoutineId }
    let expectedSurvivorItemIds = morningRoutineCopies
      .map { $0.items.map(\.id).sorted().joined(separator: ",") }
      .min()

    try SampleData.dedupeChecklists(in: context)

    let survivor = try #require(try context.checklist(id: SampleData.morningRoutineId))
    #expect(
      survivor.items.map(\.id).sorted().joined(separator: ",") == expectedSurvivorItemIds,
      "The survivor must be chosen by a rule every device computes identically.",
    )
  }

  // MARK: - An edited copy beats a fresh seed

  /// Checking a box is the most likely edit of all, and must be enough to protect a copy.
  @Test("an edited copy survives and the pristine copy goes when checked states differ")
  func editedCopyWinsWhenCheckedStatesDiffer() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    let edited = try #require(try context.fetchChecklistsSorted().first { $0.id == SampleData.preTripId })
    edited.items.first?.status = .checked
    try context.saveChanges(operation: .itemEdit)

    try SampleData.dedupeChecklists(in: context)

    let preTrips = try context.fetchChecklistsSorted().filter { $0.id == SampleData.preTripId }
    #expect(preTrips.count == 1)
    #expect(preTrips.first === edited)
  }

  @Test("an edited copy survives and the pristine copy goes when an item was added")
  func editedCopyWinsWhenAnItemWasAdded() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    let edited = try #require(try context.fetchChecklistsSorted().first { $0.id == SampleData.preTripId })
    try context.insert(item: Item(name: "One more thing"), at: 0, in: edited)

    try SampleData.dedupeChecklists(in: context)

    let preTrips = try context.fetchChecklistsSorted().filter { $0.id == SampleData.preTripId }
    #expect(preTrips.count == 1)
    #expect(preTrips.first === edited)
  }

  // MARK: - What it must refuse to touch

  /// A copy whose items are still arriving from iCloud looks just like one with items deleted.
  @Test("deletes nothing for a sample while a copy has fewer items than the fixture")
  func waitsWhileACopyHasFewerItems() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    let halfArrived = try #require(try context.fetchChecklistsSorted().first { $0.id == SampleData.weekendGetawayId })
    for item in halfArrived.items.suffix(5) {
      context.delete(item)
    }
    try context.saveChanges(operation: .delete)

    try SampleData.dedupeChecklists(in: context)

    let stored = try context.fetchChecklistsSorted()
    #expect(stored.count(where: { $0.id == SampleData.weekendGetawayId }) == 2)
    #expect(stored.count(where: { $0.id == SampleData.morningRoutineId }) == 1, "Other samples are still deduped.")
  }

  /// A copy that differs only in text — which is also how a copy seeded in another language looks —
  /// is not proof of an edit. Both copies are kept: treating it as an edit would let two devices in
  /// different languages each delete their own copy and leave none.
  @Test("keeps both copies when one differs only in text")
  func keepsBothWhenOneDiffersOnlyInText() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    let otherText = try #require(try context.fetchChecklistsSorted().first { $0.id == SampleData.morningRoutineId })
    otherText.name = "Routine du matin"
    for item in otherText.items {
      item.name = "Autre langue"
    }
    try context.saveChanges(operation: .itemEdit)

    try SampleData.dedupeChecklists(in: context)

    #expect(try context.fetchChecklistsSorted().count(where: { $0.id == SampleData.morningRoutineId }) == 2)
  }

  /// Two edited copies are both the user's data; there is no telling which one they meant to keep.
  @Test("keeps both copies when both were edited")
  func keepsBothWhenBothWereEdited() throws {
    let context = try TestModelContainer.makeContext()
    try SampleData.seed(into: context)
    try seedSecondCopy(into: context)

    for copy in try context.fetchChecklistsSorted() where copy.id == SampleData.preTripId {
      copy.items.first?.status = .checked
    }
    try context.saveChanges(operation: .itemEdit)

    try SampleData.dedupeChecklists(in: context)

    #expect(try context.fetchChecklistsSorted().count(where: { $0.id == SampleData.preTripId }) == 2)
  }

  /// Two checklists that merely look alike but carry different ids are ordinary user data, whatever
  /// their contents. This is the two-device upgrade case, and it must be left entirely alone.
  @Test("never touches checklists with different ids")
  func neverTouchesChecklistsWithDifferentIds() throws {
    let context = try TestModelContainer.makeContext()
    for _ in 0 ..< 2 {
      let checklist = Checklist(name: "Morning Routine", sortKey: 1.0)
      context.insert(checklist)
      try context.insert(item: Item(name: "START COFFEE MAKER"), at: 0, in: checklist)
    }
    try context.saveChanges(operation: .checklistEdit)

    try SampleData.dedupeChecklists(in: context)

    #expect(try context.fetchChecklistsSorted().count == 2, "Distinct ids are distinct records, however similar.")
  }
}
