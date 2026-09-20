//
//  ChecklistScreenHarness.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import SwiftData
import UIKit

/// A `ChecklistViewController` with its view loaded, in a real window, over a disposable store.
///
/// Loading the view is what most of this controller's behavior needs: the header fields, the status
/// icon and the table all come from `viewDidLoad`, and a first responder needs a key window. It
/// became testable once the controller took an injected `ModelContext` — before that it wrote
/// through `PersistenceController.shared`, which in this hosted process resolves to the app's own
/// seeded container.
///
/// Closure-scoped like `TestScope`, so teardown is not optional: the controller registers a
/// `RemoteChangeObserver` on `NotificationCenter.default`, and one left alive would keep answering
/// notifications posted by later suites.
enum ChecklistScreenHarness {
  struct Context {
    let viewController: ChecklistViewController
    let checklist: Checklist
    let modelContext: ModelContext
    let analytics: SpyAnalyticsClient

    /// `loadView` installs the table as the controller's `view`, so it is reachable without
    /// widening the controller's own private storage.
    var table: UITableView {
      guard let table = viewController.view as? UITableView else {
        fatalError("The checklist controller's view is not its table.")
      }
      return table
    }

    var header: ChecklistInfoHeaderView {
      guard let header = table.tableHeaderView as? ChecklistInfoHeaderView else {
        fatalError("The checklist header was not installed.")
      }
      return header
    }

    var itemNames: [String] {
      checklist.items.map(\.name)
    }

    /// Re-reads the checklist through a second context over the same container, to tell "saved"
    /// from "staged in the context the assertion is already looking at".
    func persistedItemNames() throws -> [String] {
      let verification = ModelContext(modelContext.container)
      return try verification.fetch(FetchDescriptor<Item>())
        .sorted { $0.sortKey < $1.sortKey }
        .map(\.name)
    }
  }

  /// - Parameters:
  ///   - items: each item's name and whether it is checked, in the order they should appear.
  ///   - isNewChecklist: drives the create-sheet wording and the history caption.
  static func withController<T>(
    name: String = "Groceries",
    items: [(name: String, isChecked: Bool)] = [],
    isNewChecklist: Bool = false,
    _ body: (Context) throws -> T
  ) throws -> T {
    let container = try TestModelContainer.make()
    let modelContext = ModelContext(container)

    let checklist = Checklist()
    checklist.name = name
    modelContext.insert(checklist)
    for (offset, item) in items.enumerated() {
      let model = Item()
      model.name = item.name
      model.sortKey = Double(offset + 1)
      model.statusRaw = (item.isChecked ? Item.Status.checked : .unchecked).rawValue
      modelContext.insert(model)
      model.checklist = checklist
    }
    try modelContext.save()

    let analytics = SpyAnalyticsClient()
    let viewController = ChecklistViewController()
    viewController.checklist = checklist
    viewController.context = modelContext
    viewController.isNewChecklist = isNewChecklist
    viewController.analytics = analytics

    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    defer {
      // Releases the controller, and with it the remote-change observer it registered.
      window.rootViewController = nil
      window.isHidden = true
    }
    window.rootViewController = viewController
    window.makeKeyAndVisible()
    viewController.loadViewIfNeeded()
    viewController.view.layoutIfNeeded()

    return try body(
      Context(
        viewController: viewController,
        checklist: checklist,
        modelContext: modelContext,
        analytics: analytics
      )
    )
  }
}
