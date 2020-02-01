//
//  SettingsViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/10/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

private let themesSection = 999 // Change back when I add this back in.
private let infoSection = 0

class SettingsViewController: UITableViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
    tableView.tableFooterView = tableFooterView(tableWidth: tableView.frame.size.width)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Flurry.logPageView()
    AnalyticsManager.logSettingsViewed()
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case themesSection:
      return 3
    case infoSection:
      return 1
    default:
      assertionFailure()
      return 0
    }
  }

  func retrieveThemeViews(from cell: UITableViewCell) -> (UILabel, RoundCheckboxButton) {
    guard
      let themeNameLabel = cell.viewWithTag(1) as? UILabel,
      let roundCheckButton = cell.viewWithTag(2) as? RoundCheckboxButton
      else { assertionFailure(); return (UILabel(), RoundCheckboxButton()) }
    return (themeNameLabel, roundCheckButton)
  }

  func retrieveInfoViews(from cell: UITableViewCell) -> (UIImageView, UILabel) {
    guard
      let imageView = cell.viewWithTag(1) as? UIImageView,
      let label = cell.viewWithTag(2) as? UILabel
      else { assertionFailure(); return (UIImageView(), UILabel()) }
    return (imageView, label)
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: UITableViewCell

    switch indexPath.section {
    case themesSection:
      cell = tableView.dequeueReusableCell(withIdentifier: "ThemeItemRow", for: indexPath)
      let (themeNameLabel, roundCheckboxButton) = retrieveThemeViews(from: cell)
      roundCheckboxButton.isUserInteractionEnabled = false // use the cell selection mechanism.
      switch indexPath.row {
      case AppTheme.defaultBougie.rawValue:
        themeNameLabel.text = "Bougie (Default)"
        roundCheckboxButton.isSelected = (AppTheme.defaultBougie == SettingsManager.currentAppTheme)
      case AppTheme.extraBougie.rawValue:
        themeNameLabel.text = "Even Cuter Bougie"
        roundCheckboxButton.isSelected = (AppTheme.extraBougie == SettingsManager.currentAppTheme)
      case AppTheme.unicorns.rawValue:
        themeNameLabel.text = "UNICORNS!!!"
        roundCheckboxButton.isSelected = (AppTheme.unicorns == SettingsManager.currentAppTheme)
      default:
        assertionFailure()
      }
    case infoSection:
      cell = tableView.dequeueReusableCell(withIdentifier: "InfoRow", for: indexPath)
      let (imageView, label) = retrieveInfoViews(from: cell)
      imageView.image = UIImage(named: "PrivacyPolicyIcon25x25")
      label.text = "Privacy Policy"
    default:
      assertionFailure()
      cell = UITableViewCell()
    }
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
    cell.isSelected = false

    switch indexPath.section {
    case themesSection:
      switch indexPath.row {
      case AppTheme.defaultBougie.rawValue:
        SettingsManager.setCurrentAppTheme(appTheme: .defaultBougie)
        print("DEFAULT")
      case AppTheme.extraBougie.rawValue:
        SettingsManager.setCurrentAppTheme(appTheme: .extraBougie)
        print("BOUGIE")
      case AppTheme.unicorns.rawValue:
        SettingsManager.setCurrentAppTheme(appTheme: .unicorns)
        print("UNICORN")
      default:
        assertionFailure()
      }
      tableView.reloadData()
    case infoSection:
      AnalyticsManager.logViewPrivacyPolicy()
      guard let url = URL(string: "https://www.termsfeed.com/privacy-policy/0420e699b562320b2beb80af0a4e08b9") else { assertionFailure(); return }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    default:
      assertionFailure()
    }
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case themesSection:
      return "THEMES"
    case infoSection:
      return "INFO"
    default:
      return nil
    }
  }

  override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    guard
      let view = view as? UITableViewHeaderFooterView,
      let textLabel = view.textLabel
      else { assertionFailure(); return }
    let backgroundView = UIView()
    backgroundView.backgroundColor = .clear
    view.backgroundView = backgroundView
    view.tintColor = Colors.defaultBackground // Not clear so if header sticks to top, things don't overlap while scrolling up.
    textLabel.font = .systemFont(ofSize: 14.0)
    textLabel.textColor = Colors.inactiveText
  }

  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return false
  }

  override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    return false
  }

  private func tableFooterView(tableWidth: CGFloat) -> UILabel {
    // Apple says that a tableFooterView is auto-sized to the proper height and width, but as of iOS 12, that doesn't seem to work.
    let label = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: tableWidth, height: 36.0))
    label.font = label.font.withSize(14.0)
    label.textColor = .lightGray
    label.textAlignment = .center
    label.text = "Version \(SettingsManager.versionBuildString)"
    return label
  }
}
