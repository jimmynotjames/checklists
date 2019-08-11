//
//  SettingsViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/10/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

private let themesSection = 0

class SettingsViewController: UITableViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
    tableView.tableFooterView = tableFooterView(tableWidth: tableView.frame.size.width)
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
    case 0:
      return 3
    default:
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

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell: UITableViewCell

    if indexPath.section == themesSection {
      let cell = tableView.dequeueReusableCell(withIdentifier: "themeItem", for: indexPath)
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
      cell.selectionStyle = .gray
      return cell
    }
    assertionFailure()
    cell = UITableViewCell()
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    if indexPath.section == themesSection {
      guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
      cell.isSelected = false

      switch indexPath.row {
      case AppTheme.defaultBougie.rawValue:
        SettingsManager.setCurretAppTheme(appTheme: .defaultBougie)
        print("DEFAULT")
      case AppTheme.extraBougie.rawValue:
        SettingsManager.setCurretAppTheme(appTheme: .extraBougie)
        print("BOUGIE")
      case AppTheme.unicorns.rawValue:
        SettingsManager.setCurretAppTheme(appTheme: .unicorns)
        print("UNICORN")
      default:
        assertionFailure()
      }
    }
    tableView.reloadData()
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case themesSection:
      return "THEMES"
    default:
      assertionFailure()
      return nil
    }
  }

  override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    guard
      let view = view as? UITableViewHeaderFooterView,
      let textLabel = view.textLabel
      else { assertionFailure(); return }
    view.backgroundColor = .clear
    view.tintColor = .clear
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
    let versionNumberString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "0.0.0"
    let buildNumberString = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "0"
    // Apple says that a tableFooterView is auto-sized to the proper height and width, but as of iOS 12, that doesn't seem to work.
    let label = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: tableWidth, height: 36.0))
    label.font = label.font.withSize(14.0)
    label.textColor = .lightGray
    label.textAlignment = .center
    label.text = "Version \(versionNumberString) (\(buildNumberString))"
    return label
  }
}
