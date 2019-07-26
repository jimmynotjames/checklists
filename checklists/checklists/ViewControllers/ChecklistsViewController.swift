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

  // MARK: - UITableViewController overrides
  override func viewDidLoad() {
    super.viewDidLoad()
    let addChecklistButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addChecklistButtonTapped))
    self.navigationItem.setRightBarButtonItems([addChecklistButton, self.editButtonItem], animated: false)

    let realm = DBManager.realm
    checklists = realm.objects(Checklist.self).sorted(byKeyPath: "sortNumber")
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if isFirstTimeLaunch {
      isFirstTimeLaunch = false
    } else {
      tableView.reloadData()
    }
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

      DBManager.write {
        let realm = DBManager.realm
        realm.delete(checklists[indexPath.row])
      }
      tableView.deleteRows(at: [indexPath], with: .fade)
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
