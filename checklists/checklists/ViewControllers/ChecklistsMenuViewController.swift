//
//  ChecklistsMoreMenuViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 11/19/20.
//  Copyright © 2020 Jimmy Ho. All rights reserved.
//

import UIKit

protocol ChecklistsMenuViewControllerDelegate: AnyObject {
  func resetAllSelected()
}

class ChecklistsMenuViewController: UITableViewController {

  weak var delegate: ChecklistsMenuViewControllerDelegate?

  override func viewDidLoad() {
    super.viewDidLoad()
    preferredContentSize = CGSize(width: 100.0, height: 40.0)
    tableView.contentInset = UIEdgeInsets(top: 10.0, left: 0.0, bottom: 0.0, right: 0.0)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "MenuItem", for: indexPath)
    cell.textLabel?.text = "Reset All"
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    delegate?.resetAllSelected()
    dismiss(animated: true, completion: nil)
  }
}
