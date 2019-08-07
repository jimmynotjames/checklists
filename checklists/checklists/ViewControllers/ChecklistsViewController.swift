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

class ChecklistsViewController: UITableViewController {

  private var isFirstTimeLaunch: Bool = true // TODO: MAY NOT NEED THIS: https://developer.apple.com/documentation/uikit/uitableviewcontroller

  private var checklists: Results<Checklist>!

  // MARK: - UITableViewController overrides
  override func viewDidLoad() {
    super.viewDidLoad()

    let realm = DBManager.realm
    checklists = realm.objects(Checklist.self).sorted(byKeyPath: "sortNumber")

    tableView.dragInteractionEnabled = true
    tableView.dragDelegate = self
    tableView.dropDelegate = self
    tableView.tableFooterView = tableFooterView(tableWidth: tableView.frame.size.width)

    let menuButton = UIBarButtonItem(image: UIImage(named: "MenuIcon25x25"), style: .plain, target: self, action: #selector(menuButtonTapped))
    navigationItem.setLeftBarButton(menuButton, animated: false)

    let addChecklistButton = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(addChecklistButtonTapped))
    navigationItem.setRightBarButton(addChecklistButton, animated: false)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if isFirstTimeLaunch {
      isFirstTimeLaunch = false
    } else {
      tableView.reloadData()
    }
  }

  @objc func addChecklistButtonTapped() {
    guard let checklistViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Checklist") as? ChecklistViewController else { assertionFailure(); return }
    let sortNumber = checklists.isEmpty ? Checklist.startingSortNumber() : Checklist.calculateSortNumber(after: checklists.last!)
    let checklist = Checklist(name: "", notes: nil, sortNumber: sortNumber, items: [])
    DBManager.write {
      DBManager.realm.add(checklist)
    }
    checklistViewController.checklist = checklist
    checklistViewController.isNewChecklist = true
    let navigationController = UINavigationController(rootViewController: checklistViewController)
    present(navigationController, animated: true, completion: nil)
  }

  @objc func menuButtonTapped() {
    presentPopoverMainMenu()
  }

  private func tableFooterView(tableWidth: CGFloat) -> UILabel {
    let versionNumberString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "0.0.0"
    // Apple says that a tableFooterView is auto-sized to the proper height and width, but as of iOS 12, that doesn't seem to work.
    let label = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: tableWidth, height: 18.0))
    label.font = label.font.withSize(14.0)
    label.textColor = .lightGray
    label.textAlignment = .center
    label.text = "(Version \(versionNumberString))"
    return label
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return checklists.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == checklistsSection {
      let cell = tableView.dequeueReusableCell(withIdentifier: "ChecklistCell", for: indexPath)
      cell.textLabel?.text = checklists[indexPath.row].name
      cell.detailTextLabel?.text = checklists[indexPath.row].notes
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
        indexPath.row < checklists.count else { assertionFailure(); return }

      let alertController = UIAlertController(title: nil, message: "Delete this checklist? This cannot be undone.", preferredStyle: .alert)
      alertController.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { alertAction in
        DBManager.write {
          DBManager.realm.delete(self.checklists[indexPath.row])
        }
        self.tableView.deleteRows(at: [indexPath], with: .fade)
      }))
      alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
      present(alertController, animated: true, completion: nil)
    } else if editingStyle == .insert {
      assertionFailure()
      // TODO: Do something else here??
    }
  }

  override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
    guard fromIndexPath.section == checklistsSection && to.section == checklistsSection else { assertionFailure(); return }

    let fromIndex = fromIndexPath.row
    let toIndex = to.row

    guard fromIndex != toIndex else { return }

    let checklist = checklists[fromIndex]
    let sortNumber: Double
    switch toIndex {
    case 0:
      sortNumber = Checklist.calculateSortNumber(before: checklists[0])
    case checklists.count - 1:
      sortNumber = Checklist.calculateSortNumber(after: checklists[checklists.count - 1])
    default:
      sortNumber = Checklist.calculateSortNumber(between: checklists[toIndex], and: checklists[toIndex+1])
    }
    DBManager.write {
      checklist.sortNumber = sortNumber
    }
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

      checklistViewController.checklist = checklists[indexPath.row]
    }
    // Get the new view controller using segue.destination.
    // Pass the selected object to the new view controller.
  }
}

// MARK: - Drag/Drop Reorder

extension ChecklistsViewController: UITableViewDragDelegate  {
  func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    guard indexPath.section == checklistsSection else { assertionFailure(); return [] }
    return checklists[indexPath.row].dragItems()
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
    let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(row: checklists.count, section: checklistsSection)
    assert(coordinator.items.count == 1)
    guard let dropItem = coordinator.items.first else { assertionFailure(); return }
    let itemProvider = dropItem.dragItem.itemProvider
    itemProvider.loadObject(ofClass: NSString.self) { string, error in
      if let checklistId = string as? String {
        if let sourceIndex = self.checklists.firstIndex(where: { checklist in return checklist.id == checklistId }) {
          Checklist.moveChecklist(from: sourceIndex, to: destinationIndexPath.row, checklists: self.checklists)
          DispatchQueue.main.async {
            tableView.moveRow(at: IndexPath(row: sourceIndex, section: destinationIndexPath.section), to: destinationIndexPath)
          }
        }
      }
    }
  }
}

extension ChecklistsViewController : MainMenuEnabledViewController {
  var baselineWidth: CGFloat { return view.frame.width }
  var popoverBarButtonItem: UIBarButtonItem { return navigationItem.leftBarButtonItem ?? UIBarButtonItem() }

  func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
    return .none
  }
}
