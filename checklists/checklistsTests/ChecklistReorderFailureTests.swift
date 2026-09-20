//
//  ChecklistReorderFailureTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import Testing
import UIKit

/// Covers what `ChecklistViewController` does when an item reorder cannot be saved.
///
/// A real SwiftData save only fails on a full or damaged disk, so the failure is injected through
/// `saveItemMove` rather than provoked — the same closure-injection seam
/// `ProductionContainerFactoryTests` uses for container creation.
///
/// These tests deliberately never load the view: `tableView(_:moveRowAt:to:)` reads only the
/// checklist and the injected context, so there is nothing a loaded view would add.
@Suite("Recovering from a failed item reorder save")
struct ChecklistReorderFailureTests {
  /// Records resync requests instead of touching a table view that was never loaded.
  private final class SpyViewController: ChecklistViewController {
    var resyncCount = 0

    override func resyncAfterFailedMove() {
      resyncCount += 1
    }
  }

  private struct SaveFailure: Error {}

  private let sourceIndexPath = IndexPath(row: 0, section: 0)
  private let destinationIndexPath = IndexPath(row: 2, section: 0)

  /// A checklist with three named items, in a container that lives only for this test.
  private func makeChecklist() throws -> (Checklist, ModelContext) {
    let container = try TestModelContainer.make()
    let context = ModelContext(container)
    let checklist = Checklist()
    context.insert(checklist)
    for (offset, name) in ["first", "second", "third"].enumerated() {
      let item = Item()
      item.name = name
      item.sortKey = Double(offset + 1)
      item.checklist = checklist
      context.insert(item)
    }
    try context.save()
    return (checklist, context)
  }

  private func makeViewController(for checklist: Checklist, context: ModelContext) -> SpyViewController {
    let viewController = SpyViewController()
    viewController.checklist = checklist
    viewController.context = context
    return viewController
  }

  @Test("a failed move asks for a resync")
  func failedMoveAsksForAResync() throws {
    let (checklist, context) = try makeChecklist()
    let viewController = makeViewController(for: checklist, context: context)
    viewController.saveItemMove = { _, _, _ in throw SaveFailure() }

    viewController.tableView(UITableView(), moveRowAt: sourceIndexPath, to: destinationIndexPath)

    #expect(viewController.resyncCount == 1, "A move that could not be saved must resync the table from the store.")
  }

  @Test("a successful move does not resync")
  func successfulMoveDoesNotResync() throws {
    let (checklist, context) = try makeChecklist()
    let viewController = makeViewController(for: checklist, context: context)
    var recordedIndex: Int?
    viewController.saveItemMove = { _, _, index in recordedIndex = index }

    viewController.tableView(UITableView(), moveRowAt: sourceIndexPath, to: destinationIndexPath)

    #expect(recordedIndex == destinationIndexPath.row, "The destination row is what the reorder helper expects as its index.")
    #expect(viewController.resyncCount == 0, "A save that succeeded leaves the table agreeing with the store already.")
  }

  /// With no override, the write has to be *saved through* the context this controller was given.
  ///
  /// The regression net for the injection itself: the old default saved through
  /// `PersistenceController.shared`, which in this hosted test process resolves to the app's own
  /// seeded container. Asserting the resulting order does not catch that — `move` mutates `sortKey`
  /// on these objects either way, and a fetch sees the context's own pending changes. `hasChanges`
  /// is the discriminator: it is only cleared by a save on *this* context, so it stays true when
  /// the save went somewhere else.
  @Test("the default save path saves through the injected context")
  func defaultSavePathUsesTheInjectedContext() throws {
    let (checklist, context) = try makeChecklist()
    let viewController = makeViewController(for: checklist, context: context)

    viewController.tableView(UITableView(), moveRowAt: sourceIndexPath, to: destinationIndexPath)

    #expect(viewController.resyncCount == 0)
    #expect(checklist.items.map(\.name) == ["second", "third", "first"])
    #expect(!context.hasChanges, "The reorder was saved through some other context.")
  }

  /// `saveMove` reports the outcome so the drop path can decline to move a row it failed to save;
  /// that path itself needs a `UITableViewDropCoordinator`, which cannot be constructed in a test.
  @Test("saveMove reports whether it saved")
  func saveMoveReportsWhetherItSaved() throws {
    let (checklist, context) = try makeChecklist()
    let viewController = makeViewController(for: checklist, context: context)
    let items = checklist.items

    viewController.saveItemMove = { _, _, _ in }
    #expect(viewController.saveMove(of: items[0], among: items, to: 2))

    viewController.saveItemMove = { _, _, _ in throw SaveFailure() }
    #expect(!viewController.saveMove(of: items[0], among: items, to: 2))
  }

  // MARK: - The restore itself

  /// The heart of the fix. A reorder assigns sort keys before it saves, and the screens read the
  /// order back out of the context rather than off disk, so a failed save has to leave those keys
  /// exactly as it found them — otherwise the unsaved order goes on being displayed as though it
  /// had been written.
  @Test("a failed save leaves every sort key as it was")
  func failedSaveLeavesEverySortKeyAsItWas() throws {
    let (checklist, context) = try makeChecklist()
    let items = checklist.items
    let keysBefore = items.map(\.sortKey)

    #expect(throws: (any Error).self) {
      try context.placeAndSave(items[0], at: 2, among: Array(items.dropFirst()), restoringSortKeysOf: items) {
        throw SaveFailure()
      }
    }

    #expect(items.map(\.sortKey) == keysBefore)
    #expect(checklist.items.map(\.name) == ["first", "second", "third"], "The displayed order comes from those keys, so it must be unchanged too.")
  }

  /// The same path on success, to prove the restore is not simply undoing every move.
  @Test("a successful save keeps the new order")
  func successfulSaveKeepsTheNewOrder() throws {
    let (checklist, context) = try makeChecklist()
    let items = checklist.items

    try context.placeAndSave(items[0], at: 2, among: Array(items.dropFirst()), restoringSortKeysOf: items) {
      try context.save()
    }

    #expect(checklist.items.map(\.name) == ["second", "third", "first"])
  }
}
