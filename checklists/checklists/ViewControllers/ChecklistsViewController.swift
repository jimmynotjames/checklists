//
//  ChecklistsViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 6/7/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit
import RealmSwift

class ChecklistsViewController: UITableViewController {

  private let checklistsSection = 0
  private var isFirstTimeLaunch: Bool = true

  private var checklists: Results<Checklist>!

  // MARK: - UITableViewController overrides
  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationItem.rightBarButtonItem = self.editButtonItem

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
    let cell = tableView.dequeueReusableCell(withIdentifier: "ChecklistCell", for: indexPath)
    cell.textLabel?.text = checklists[indexPath.row].name
    cell.detailTextLabel?.text = checklists[indexPath.row].notes
    return cell
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
      sortNumber = checklist.calculateSortNumber(before: checklists[0])
    case checklists.count - 1:
      sortNumber = checklist.calculateSortNumber(after: checklists[checklists.count - 1])
    default:
      sortNumber = checklist.calculateSortNumber(between: checklists[toIndex], and: checklists[toIndex+1])
    }
    DBManager.write {
      checklist.sortNumber = sortNumber
    }
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return indexPath.section == checklistsSection
  }

  /*
   // MARK: - Navigation

   // In a storyboard-based application, you will often want to do a little preparation before navigation
   override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
   // Get the new view controller using segue.destination.
   // Pass the selected object to the new view controller.
   }
   */

}
