//
//  ChecklistsViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/7/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit
import RealmSwift

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
    self.group = mainGroup

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
    let views = [ "button": addChecklistButton ]
    views.forEach({ $0.value.translatesAutoresizingMaskIntoConstraints = false })

    let baseOffset: CGFloat = UIApplication.shared.windows.filter({$0.isKeyWindow}).first?.safeAreaInsets.bottom ?? 0.0
    let bottomOffset: CGFloat = -20.0 + baseOffset

    addChecklistButtonPortraitConstraints = [
      addChecklistButton.bottomAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.bottomAnchor, constant: bottomOffset),
      addChecklistButton.rightAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.rightAnchor, constant: -20.0)
    ]
    addChecklistButtonLandscapeConstraints = [
      addChecklistButton.bottomAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.bottomAnchor, constant: -20.0),
      addChecklistButton.rightAnchor.constraint(equalTo: tableView.safeAreaLayoutGuide.rightAnchor, constant: bottomOffset)
    ]
    updateAddChecklistButtonConstraints()
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
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
    guard let checklistViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Checklist") as? ChecklistViewController else { assertionFailure(); return }
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
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let menuViewController = storyboard.instantiateViewController(withIdentifier: "ChecklistsMoreMenu") as? ChecklistsMenuViewController else { assertionFailure(); return }

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

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return group.checklists.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == checklistsSection {
      guard let cell = tableView.dequeueReusableCell(withIdentifier: "ChecklistCellWithStatus", for: indexPath) as? ChecklistTableViewCell else { assertionFailure("ChecklistCellWithStatus"); return UITableViewCell() }
      cell.checklist = group.checklists[indexPath.row]
      return cell
    } else {
      assertionFailure()
      return UITableViewCell()
    }
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return indexPath.section == checklistsSection
  }

  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      guard
        indexPath.section == checklistsSection &&
        indexPath.row >= 0 &&
        indexPath.row < group.checklists.count else { assertionFailure(); return }

      let alertController = UIAlertController(title: nil, message: "Are you sure? This cannot be undone.", preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { alertAction in
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

  override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
    guard fromIndexPath.section == checklistsSection && to.section == checklistsSection else { assertionFailure(); return }
    group.moveChecklist(from: fromIndexPath.row, to: to.row)
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return indexPath.section == checklistsSection
  }

  // MARK: - Navigation

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let identifier = segue.identifier,
      identifier == "showChecklist",
      let checklistViewController = segue.destination as? ChecklistViewController,
      let cell = sender as? UITableViewCell,
      let indexPath = tableView.indexPath(for: cell) {

      checklistViewController.checklist = group.checklists[indexPath.row]
      checklistViewController.delegate = self
    }
  }
}

extension ChecklistsViewController: ChecklistViewControllerDelegate {
  func willDismissChecklistViewController(_ ChecklistViewController: ChecklistViewController) {
    tableView.reloadData()
  }
}

// MARK: - Drag/Drop Reorder

extension ChecklistsViewController: UITableViewDragDelegate  {
  func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    guard indexPath.section == checklistsSection else { assertionFailure(); return [] }
    return group.checklists[indexPath.row].dragItems()
  }
}

extension ChecklistsViewController: UITableViewDropDelegate {
  func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
    return session.canLoadObjects(ofClass: NSString.self)
  }

  func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
    if tableView.hasActiveDrag {
      if session.items.count > 1 {
        return UITableViewDropProposal(operation: .cancel)
      } else {
        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
      }
    } else { // dropped from external to app
      return UITableViewDropProposal(operation: .cancel)
    }
  }

  func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
    let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(row: group.checklists.count, section: checklistsSection)
    assert(coordinator.items.count == 1)
    guard let dropItem = coordinator.items.first else { assertionFailure(); return }
    let itemProvider = dropItem.dragItem.itemProvider
    itemProvider.loadObject(ofClass: NSString.self) { string, error in
      if let checklistId = string as? String {
        if let sourceIndex = self.group.checklists.firstIndex(where: { checklist in return checklist.id == checklistId }) {
          self.group.moveChecklist(from: sourceIndex, to: destinationIndexPath.row)
          DispatchQueue.main.async {
            tableView.moveRow(at: IndexPath(row: sourceIndex, section: destinationIndexPath.section), to: destinationIndexPath)
          }
        }
      }
    }
  }
}

extension ChecklistsViewController: MainMenuTableViewControllerDelegate {
  func openSettingsPage() {
    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
    let settingsViewController = storyBoard.instantiateViewController(withIdentifier: "Settings")
    present(settingsViewController, animated: true)
  }

  func openDonatePage() {
    let storyBoard = UIStoryboard(name: "Main", bundle: nil)
    let donateViewController = storyBoard.instantiateViewController(withIdentifier: "Donate")
    present(donateViewController, animated: true)
  }
}

// This is here to force iPhone devices to use the popover style instead of switching over to a form sheet or something.
extension ChecklistsViewController: UIPopoverPresentationControllerDelegate {
  func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
    return .none
  }
}

extension ChecklistsViewController: ChecklistsMenuViewControllerDelegate {
  func resetAllSelected() {
    dismiss(animated: true, completion: nil) // Dismissing the menu, otherwise, can't present this one.
    let alertController = UIAlertController(title: nil, message: "Are you sure? This cannot be undone.", preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "Reset All", style: .destructive, handler: { alertAction in
      self.resetAllChecklists()
    }))
    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    present(alertController, animated: true, completion: nil)
  }
}
