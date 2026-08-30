//
//  ChecklistsMenuViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 11/19/20.
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

    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "MenuItem")
    tableView.separatorStyle = .singleLine
    tableView.isScrollEnabled = false
    tableView.showsVerticalScrollIndicator = false
    tableView.showsHorizontalScrollIndicator = false
  }

  // MARK: - Table view data source

  override func numberOfSections(in _: UITableView) -> Int {
    1
  }

  override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    1
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "MenuItem", for: indexPath)
    cell.textLabel?.text = "Reset All"
    cell.textLabel?.font = .systemFont(ofSize: 17.0)
    cell.textLabel?.textColor = Colors.teal
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    delegate?.resetAllSelected()
    dismiss(animated: true, completion: nil)
  }
}
