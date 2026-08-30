//
//  SettingsViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/10/19.
//

import UIKit

private let themesSection = 999 // Change back when I add this back in.
private let infoSection = 0

class SettingsViewController: UITableViewController {
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))

    tableView.backgroundColor = Colors.defaultBackground
    tableView.sectionIndexColor = Colors.inactiveText
    tableView.separatorStyle = .none
    tableView.sectionHeaderHeight = 18
    tableView.sectionFooterHeight = 18
    tableView.register(ThemeItemTableViewCell.self, forCellReuseIdentifier: "ThemeItemRow")
    tableView.register(InfoRowTableViewCell.self, forCellReuseIdentifier: "InfoRow")

    tableView.tableHeaderView = settingsHeaderView(tableWidth: tableView.frame.size.width)
    tableView.tableFooterView = tableFooterView(tableWidth: tableView.frame.size.width)
  }

  private func settingsHeaderView(tableWidth: CGFloat) -> UIView {
    let headerView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: tableWidth, height: 66.0))

    let titleLabel = UILabel()
    titleLabel.text = "Settings"
    titleLabel.font = .systemFont(ofSize: 24.0, weight: .semibold)

    headerView.addSubview(titleLabel)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 14.0),
      titleLabel.leadingAnchor.constraint(equalTo: headerView.layoutMarginsGuide.leadingAnchor, constant: 8.0),
      titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16.0),
      titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20.0),
    ])
    return headerView
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    AnalyticsManager.logSettingsViewed()
  }

  @objc func doneButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  // MARK: - Table view data source

  override func numberOfSections(in _: UITableView) -> Int {
    1
  }

  override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
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

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case themesSection:
      guard let cell = tableView.dequeueReusableCell(withIdentifier: "ThemeItemRow", for: indexPath) as? ThemeItemTableViewCell
      else { assertionFailure(); return UITableViewCell() }
      cell.checkboxButton.isUserInteractionEnabled = false // use the cell selection mechanism.
      switch indexPath.row {
      case AppTheme.defaultBougie.rawValue:
        cell.nameLabel.text = "Bougie (Default)"
        cell.checkboxButton.isSelected = (AppTheme.defaultBougie == SettingsManager.currentAppTheme)
      case AppTheme.extraBougie.rawValue:
        cell.nameLabel.text = "Even Cuter Bougie"
        cell.checkboxButton.isSelected = (AppTheme.extraBougie == SettingsManager.currentAppTheme)
      case AppTheme.unicorns.rawValue:
        cell.nameLabel.text = "UNICORNS!!!"
        cell.checkboxButton.isSelected = (AppTheme.unicorns == SettingsManager.currentAppTheme)
      default:
        assertionFailure()
      }
      return cell
    case infoSection:
      guard let cell = tableView.dequeueReusableCell(withIdentifier: "InfoRow", for: indexPath) as? InfoRowTableViewCell
      else { assertionFailure(); return UITableViewCell() }
      cell.iconImageView.image = UIImage(named: "PrivacyPolicyIcon25x25")
      cell.nameLabel.text = "Privacy Policy"
      return cell
    default:
      assertionFailure()
      return UITableViewCell()
    }
  }

  override func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    switch indexPath.section {
    case themesSection:
      48.0
    default:
      // Info rows self-size (nameLabel wraps to 2 lines), matching the storyboard's automatic row height.
      UITableView.automaticDimension
    }
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

  override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case themesSection:
      "THEMES"
    case infoSection:
      "INFO"
    default:
      nil
    }
  }

  override func tableView(_: UITableView, willDisplayHeaderView view: UIView, forSection _: Int) {
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

  override func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
    false
  }

  override func tableView(_: UITableView, canMoveRowAt _: IndexPath) -> Bool {
    false
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
