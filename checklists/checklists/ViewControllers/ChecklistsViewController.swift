//
//  ChecklistsViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/7/19.
//

import SwiftData
import UIKit

private let checklistsSection = 0

class ChecklistsViewController: UITableViewController, MainMenuEnabledViewController {
  /// The checklists in display order, refetched rather than observed.
  ///
  /// SwiftData relationships are unordered, so display order has to come from a sorted fetch (see
  /// `ModelContext.fetchChecklistsSorted`). Caching the result keeps the table view's data source
  /// answering from one consistent snapshot for the duration of a run loop turn, instead of
  /// re-sorting on every row callback.
  private var checklists: [Checklist] = []

  private var remoteChangeObserver: RemoteChangeObserver?

  private var context: ModelContext {
    PersistenceController.shared.mainContext
  }

  private let addChecklistButton = CLCircleButton.addChecklistButton()
  private var addChecklistButtonPortraitConstraints: [NSLayoutConstraint] = []
  private var addChecklistButtonLandscapeConstraints: [NSLayoutConstraint] = []
  private var addChecklistButtonActiveConstraints: [NSLayoutConstraint] = []

  // MARK: - UITableViewController overrides

  override func viewDidLoad() {
    super.viewDidLoad()

    refetchChecklists()

    // Refreshes when another device's changes are merged in. Inert until CloudKit is switched on.
    remoteChangeObserver = RemoteChangeObserver { [weak self] in
      self?.reloadChecklists()
    }

    tableView.register(ChecklistTableViewCell.self, forCellReuseIdentifier: "ChecklistCellWithStatus")
    tableView.separatorStyle = .none
    tableView.sectionHeaderHeight = 28
    tableView.sectionFooterHeight = 28
    tableView.backgroundColor = Colors.defaultBackground
    navigationItem.backBarButtonItem = UIBarButtonItem(title: " ", style: .plain, target: nil, action: nil)

    tableView.dragInteractionEnabled = true
    tableView.dragDelegate = self
    tableView.dropDelegate = self

    let menuButton = UIBarButtonItem(image: UIImage(named: "MenuIcon25x25"), style: .plain, target: self, action: #selector(menuButtonTapped))
    menuButton.accessibilityLabel = "Miscellaneous Menu"
    navigationItem.setLeftBarButton(menuButton, animated: false)

    let rightMenuButton = UIBarButtonItem(image: UIImage(named: "MoreMenuIcon32x32"), style: .plain, target: self, action: #selector(moreMenuButtonTapped))
    menuButton.accessibilityLabel = "Checklists Menu"
    navigationItem.setRightBarButton(rightMenuButton, animated: false)

    setUpAddChecklistButton()
  }

  private func setUpAddChecklistButton() {
    addChecklistButton.addTarget(self, action: #selector(addChecklistButtonTapped), for: .touchUpInside)

    tableView.addSubview(addChecklistButton)
    let views = ["button": addChecklistButton]
    views.forEach { $0.value.translatesAutoresizingMaskIntoConstraints = false }

    let baseOffset: CGFloat = view.window?.safeAreaInsets.bottom ?? 0.0
    let bottomOffset: CGFloat = -20.0 + baseOffset

    addChecklistButtonPortraitConstraints = [
      addChecklistButton.bottomAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.bottomAnchor, constant: bottomOffset),
      addChecklistButton.rightAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.rightAnchor, constant: -20.0),
    ]
    addChecklistButtonLandscapeConstraints = [
      addChecklistButton.bottomAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.bottomAnchor, constant: -20.0),
      addChecklistButton.rightAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.rightAnchor, constant: bottomOffset),
    ]
    updateAddChecklistButtonConstraints()
  }

  override func viewWillTransition(to _: CGSize, with _: UIViewControllerTransitionCoordinator) {
    updateAddChecklistButtonConstraints()
  }

  func updateAddChecklistButtonConstraints() {
    NSLayoutConstraint.deactivate(addChecklistButtonActiveConstraints)
    if UIDevice.current.orientation.isLandscape {
      addChecklistButtonActiveConstraints = addChecklistButtonLandscapeConstraints
    } else {
      addChecklistButtonActiveConstraints = addChecklistButtonPortraitConstraints
    }
    NSLayoutConstraint.activate(addChecklistButtonActiveConstraints)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    AnalyticsManager.logChecklistsViewed(numChecklists: checklists.count)
  }

  @objc func addChecklistButtonTapped() {
    AnalyticsManager.logNewChecklist()
    let checklistViewController = ChecklistViewController()
    let checklist = Checklist()
    do {
      try context.insert(checklist: checklist, at: 0, among: checklists)
    } catch {
      return // Already logged and reported by `saveChanges`; nothing was added.
    }
    refetchChecklists()
    checklistViewController.checklist = checklist
    checklistViewController.delegate = self
    checklistViewController.isNewChecklist = true
    let navigationController = UINavigationController(rootViewController: checklistViewController)
    present(navigationController, animated: true) {
      self.tableView.setContentOffset(CGPoint(x: 0.0, y: 0.0), animated: false)
    }
  }

  @objc func menuButtonTapped() {
    presentMainMenuModal()
  }

  @objc func moreMenuButtonTapped() {
    let menuViewController = ChecklistsMenuViewController(style: .plain)

    menuViewController.modalPresentationStyle = .popover
    menuViewController.popoverPresentationController?.delegate = self
    menuViewController.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
    menuViewController.delegate = self
    present(menuViewController, animated: true)
  }

  private func resetAllChecklists() {
    for checklist in checklists {
      checklist.uncheckAllItems()
    }
    context.saveChangesIgnoringFailure(operation: .checklistEdit)
    tableView.reloadData() // To reset all the status icons.
  }

  // MARK: - Fetching

  /// Refreshes the cache without touching the table view, for paths that animate their own change.
  private func refetchChecklists() {
    do {
      checklists = try context.fetchChecklistsSorted()
    } catch let error as NSError {
      AppLog.persistence.error(
        "Fetching checklists failed: \(error.domain, privacy: .public) \(error.code, privacy: .public)"
      )
      checklists = []
    }
  }

  /// Refreshes the cache and reloads the whole table. For changes this screen did not make.
  func reloadChecklists() {
    refetchChecklists()
    tableView.reloadData()
  }

  // MARK: - Table view data source

  override func numberOfSections(in _: UITableView) -> Int {
    1
  }

  override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    checklists.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == checklistsSection {
      guard let cell = tableView.dequeueReusableCell(withIdentifier: "ChecklistCellWithStatus", for: indexPath) as? ChecklistTableViewCell
      else { assertionFailure("ChecklistCellWithStatus"); return UITableViewCell() }
      cell.checklist = checklists[indexPath.row]
      return cell
    } else {
      assertionFailure()
      return UITableViewCell()
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard indexPath.section == checklistsSection else { assertionFailure(); return }
    let checklistViewController = ChecklistViewController()
    checklistViewController.checklist = checklists[indexPath.row]
    checklistViewController.delegate = self
    navigationController?.pushViewController(checklistViewController, animated: true)
  }

  override func tableView(_: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    indexPath.section == checklistsSection
  }

  override func tableView(_: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      guard
        indexPath.section == checklistsSection,
        indexPath.row >= 0,
        indexPath.row < checklists.count else { assertionFailure(); return }

      let alertController = UIAlertController(title: nil, message: "Are you sure? This cannot be undone.", preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
        guard indexPath.row < self.checklists.count else { assertionFailure(); return }
        // The items go with it: the relationship's cascade delete rule replaces the explicit
        // two-step delete Realm needed, which had no cascade of its own.
        self.context.delete(self.checklists[indexPath.row])
        self.context.saveChangesIgnoringFailure(operation: .delete)
        self.refetchChecklists()
        self.tableView.deleteRows(at: [indexPath], with: .fade)
      }))
      alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
      present(alertController, animated: true, completion: nil)
    } else if editingStyle == .insert {
      assertionFailure()
    }
  }

  override func tableView(_: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
    guard fromIndexPath.section == checklistsSection, to.section == checklistsSection else { assertionFailure(); return }
    guard fromIndexPath.row < checklists.count else { assertionFailure(); return }
    try? context.move(checklist: checklists[fromIndexPath.row], among: checklists, to: to.row)
    refetchChecklists()
  }

  override func tableView(_: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    indexPath.section == checklistsSection
  }
}

extension ChecklistsViewController: ChecklistViewControllerDelegate {
  func willDismissChecklistViewController(_: ChecklistViewController) {
    reloadChecklists()
  }
}

// MARK: - Drag/Drop Reorder

extension ChecklistsViewController: UITableViewDragDelegate {
  func tableView(_: UITableView, itemsForBeginning _: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    guard indexPath.section == checklistsSection else { assertionFailure(); return [] }
    guard indexPath.row < checklists.count else { assertionFailure(); return [] }
    return checklists[indexPath.row].dragItems()
  }
}

extension ChecklistsViewController: UITableViewDropDelegate {
  func tableView(_: UITableView, canHandle session: UIDropSession) -> Bool {
    session.canLoadObjects(ofClass: NSString.self)
  }

  func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath _: IndexPath?) -> UITableViewDropProposal {
    if tableView.hasActiveDrag {
      if session.items.count > 1 {
        UITableViewDropProposal(operation: .cancel)
      } else {
        UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
      }
    } else { // dropped from external to app
      UITableViewDropProposal(operation: .cancel)
    }
  }

  func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
    // See the matching comment in ChecklistViewController.performDropWith: the reorder below copes
    // with one past the end, but `tableView.moveRow` would not. Clamp to the last valid index.
    let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(row: checklists.count - 1, section: checklistsSection)
    assert(coordinator.items.count == 1)
    guard let dropItem = coordinator.items.first else { assertionFailure(); return }
    let itemProvider = dropItem.dragItem.itemProvider
    itemProvider.loadObject(ofClass: NSString.self) { string, _ in
      guard let checklistId = string as? String else { return }
      Task { @MainActor in
        guard let sourceIndex = self.checklists.firstIndex(where: { $0.id == checklistId }) else { return }
        try? self.context.move(checklist: self.checklists[sourceIndex], among: self.checklists, to: destinationIndexPath.row)
        self.refetchChecklists()
        tableView.moveRow(at: IndexPath(row: sourceIndex, section: destinationIndexPath.section), to: destinationIndexPath)
      }
    }
  }
}

extension ChecklistsViewController: MainMenuTableViewControllerDelegate {
  func openSettingsPage() {
    let settingsViewController = SettingsViewController(style: .grouped)
    let navigationController = UINavigationController(rootViewController: settingsViewController)
    present(navigationController, animated: true)
  }
}

/// This is here to force iPhone devices to use the popover style instead of switching over to a form sheet or something.
extension ChecklistsViewController: UIPopoverPresentationControllerDelegate {
  func adaptivePresentationStyle(for _: UIPresentationController, traitCollection _: UITraitCollection) -> UIModalPresentationStyle {
    .none
  }
}

extension ChecklistsViewController: ChecklistsMenuViewControllerDelegate {
  func resetAllSelected() {
    dismiss(animated: true, completion: nil) // Dismissing the menu, otherwise, can't present this one.
    let alertController = UIAlertController(title: nil, message: "Are you sure? This cannot be undone.", preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "Reset All", style: .destructive, handler: { _ in
      self.resetAllChecklists()
    }))
    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(alertController, animated: true, completion: nil)
  }
}
