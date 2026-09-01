//
//  ChecklistsViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/7/19.
//

import RealmSwift
import UIKit

private let checklistsSection = 0

class ChecklistsViewController: UITableViewController, MainMenuEnabledViewController {
  private var group: Group!

  private let addChecklistButton = CLCircleButton.addChecklistButton()
  private var addChecklistButtonPortraitConstraints: [NSLayoutConstraint] = []
  private var addChecklistButtonLandscapeConstraints: [NSLayoutConstraint] = []
  private var addChecklistButtonActiveConstraints: [NSLayoutConstraint] = []

  // MARK: - UITableViewController overrides

  override func viewDidLoad() {
    super.viewDidLoad()

    let realm = DBManager.realm
    guard let mainGroup = realm.objects(Group.self).first else { fatalError("Expected a Group object but none in database.") }
    group = mainGroup

    tableView.register(ChecklistTableViewCell.self, forCellReuseIdentifier: "ChecklistCellWithStatus")
    tableView.rowHeight = 107
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
    AnalyticsManager.logChecklistsViewed(numChecklists: group.checklists.count)
  }

  @objc func addChecklistButtonTapped() {
    AnalyticsManager.logNewChecklist()
    let checklistViewController = ChecklistViewController()
    let checklist = Checklist(name: "", notes: nil, items: [])
    DBManager.write {
      DBManager.realm.add(checklist)
      group.checklists.insert(checklist, at: 0)
    }
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
    for checklist in group.checklists {
      checklist.uncheckAllItems()
    }
    tableView.reloadData() // To reset all the status icons.
  }

  // MARK: - Table view data source

  override func numberOfSections(in _: UITableView) -> Int {
    1
  }

  override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    group.checklists.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == checklistsSection {
      guard let cell = tableView.dequeueReusableCell(withIdentifier: "ChecklistCellWithStatus", for: indexPath) as? ChecklistTableViewCell
      else { assertionFailure("ChecklistCellWithStatus"); return UITableViewCell() }
      cell.checklist = group.checklists[indexPath.row]
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
    checklistViewController.checklist = group.checklists[indexPath.row]
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
        indexPath.row < group.checklists.count else { assertionFailure(); return }

      let alertController = UIAlertController(title: nil, message: "Are you sure? This cannot be undone.", preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
        DBManager.write {
          let checklist = self.group.checklists[indexPath.row]
          DBManager.realm.delete(checklist.items)
          DBManager.realm.delete(checklist)
        }
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
    group.moveChecklist(from: fromIndexPath.row, to: to.row)
  }

  override func tableView(_: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    indexPath.section == checklistsSection
  }
}

extension ChecklistsViewController: ChecklistViewControllerDelegate {
  func willDismissChecklistViewController(_: ChecklistViewController) {
    tableView.reloadData()
  }
}

// MARK: - Drag/Drop Reorder

extension ChecklistsViewController: UITableViewDragDelegate {
  func tableView(_: UITableView, itemsForBeginning _: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    guard indexPath.section == checklistsSection else { assertionFailure(); return [] }
    return group.checklists[indexPath.row].dragItems()
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
    // See the matching comment in ChecklistViewController.performDropWith: falling back to one past
    // the end desyncs the model (Group.moveChecklist guards `toIndex < count`) from the table view
    // (tableView.moveRow runs unconditionally). Clamp to the last valid index instead.
    let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(row: group.checklists.count - 1, section: checklistsSection)
    assert(coordinator.items.count == 1)
    guard let dropItem = coordinator.items.first else { assertionFailure(); return }
    let itemProvider = dropItem.dragItem.itemProvider
    itemProvider.loadObject(ofClass: NSString.self) { string, _ in
      guard let checklistId = string as? String else { return }
      Task { @MainActor in
        guard let sourceIndex = self.group.checklists.firstIndex(where: { $0.id == checklistId }) else { return }
        self.group.moveChecklist(from: sourceIndex, to: destinationIndexPath.row)
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
