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
/// icon and the table all come from `viewDidLoad`. The window is needed too — `becomeFirstResponder`
/// and `view.endEditing` are both no-ops without one — and the controller's injected `ModelContext`
/// is what lets a test see what any of it wrote.
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

    /// This checklist's item names, read through a second context over the same container, to tell
    /// "saved" from "staged in the context the assertion is already looking at".
    func persistedItemNames() throws -> [String] {
      let verification = ModelContext(modelContext.container)
      let checklistId = checklist.id
      return try verification.fetch(FetchDescriptor<Item>())
        .filter { $0.checklist?.id == checklistId }
        .sorted { $0.sortKey < $1.sortKey }
        .map(\.name)
    }
  }

  /// - Parameter items: each item's name and whether it is checked, in the order they should
  ///   appear.
  static func withController<T>(
    name: String = "Groceries",
    items: [(name: String, isChecked: Bool)] = [],
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
    viewController.analytics = analytics

    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    defer {
      // Lets the controller go once this frame exits, and with it the remote-change observer the
      // controller registered. Anything the closure captured that reaches the controller will
      // outlive that, so don't capture the harness in a callback.
      window.rootViewController = nil
      window.isHidden = true
    }
    window.rootViewController = viewController
    // Visible, not key: the window has no scene here, so it cannot take key status from the test
    // host — but being unhidden is what makes first-responder changes work.
    window.isHidden = false
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
