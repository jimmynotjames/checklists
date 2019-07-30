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
    mainMenuViewController.preferredContentSize = CGSize(width: baselineWidth * 0.58, height: mainMenuViewController.preferredHeight)
    mainMenuViewController.popoverPresentationController?.delegate = self
    mainMenuViewController.popoverPresentationController?.barButtonItem = popoverBarButtonItem
    self.present(mainMenuViewController, animated: true, completion: nil)
  }
}

class MainMenuTableViewController: UITableViewController {

  var preferredHeight: CGFloat = 238.0

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.contentInset = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 0.0, right: 0.0)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    // #warning Incomplete implementation, return the number of rows
    return 5
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "navigationMenuItem", for: indexPath)
    let text: String
    switch indexPath.row {
    case 0:
      text = "Feedback"
      cell.imageView?.image = UIImage(named: "FeedbackIcon25x25")
    case 1:
      text = "Rate in App Store"
      cell.imageView?.image = UIImage(named: "RateInAppStore25x25")
    case 2:
      text = "Donate!"
      cell.imageView?.image = UIImage(named: "DonateIcon25x25")
    case 3:
      text = "About"
      cell.imageView?.image = UIImage(named: "AboutMeIcon25x25")
    case 4:
      text = "Privacy Policy"
      cell.imageView?.image = UIImage(named: "PrivacyPolicyIcon25x25")
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
