//
//  MainMenuTableViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 7/28/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

protocol MainMenuEnabledViewController: UIPopoverPresentationControllerDelegate {
  var baselineWidth: CGFloat { get } // Width of the presenting view controller's view.
  var popoverBarButtonItem: UIBarButtonItem { get } // The popover will hang off of this.

  func presentPopoverMainMenu()
}

extension MainMenuEnabledViewController where Self: UIViewController {
  func presentPopoverMainMenu() {
    guard let mainMenuViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MainMenu") as? MainMenuTableViewController else { assertionFailure(); return }
    mainMenuViewController.modalPresentationStyle = .popover
    mainMenuViewController.preferredContentSize = CGSize(width: baselineWidth * 0.55, height: mainMenuViewController.preferredHeight)
    mainMenuViewController.popoverPresentationController?.delegate = self
    mainMenuViewController.popoverPresentationController?.barButtonItem = popoverBarButtonItem
    self.present(mainMenuViewController, animated: true, completion: nil)
  }
}

class MainMenuTableViewController: UITableViewController {

  var preferredHeight: CGFloat = 265.0

  override func viewDidLoad() {
    super.viewDidLoad()
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return 6
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "navigationMenuItem", for: indexPath)
    let text: String
    switch indexPath.row {
    case 0:
      text = "Checklists"
    case 1:
      text = "Donate"
    case 2:
      text = "Feedback"
    case 3:
      text = "Rate in App Store"
    case 4:
      text = "About"
    case 5:
      text = "Privacy Policy"
    default:
      assertionFailure()
      text = ""
    }
    cell.textLabel?.text = text
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

  }
}
