//
//  SettingsViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 8/10/19.
//

import CloudKit
import UIKit

private let themesSection = 999 // Change back when I add this back in.
private let iCloudSection = 0
private let infoSection = 1

class SettingsViewController: UITableViewController {
  /// Loads the iCloud account status on appearance, then watches for account changes for as long
  /// as Settings stays on screen. Cancelled in `viewDidDisappear` so it doesn't keep running (or
  /// keep `self` alive) once the screen is dismissed.
  private var iCloudStatusTask: Task<Void, Never>?

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
    tableView.register(SyncStatusTableViewCell.self, forCellReuseIdentifier: "SyncStatusRow")

    tableView.tableHeaderView = settingsHeaderView(tableWidth: tableView.frame.size.width)
    tableView.tableFooterView = tableFooterView(tableWidth: tableView.frame.size.width)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    // Cancel first: `viewWillAppear` can run twice without an intervening `viewDidDisappear` —
    // an interactive dismiss the user aborts, for one — and the previous task would otherwise keep
    // observing and keep `self` alive.
    iCloudStatusTask?.cancel()
    iCloudStatusTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await ICloudStatusLoader().load(into: PersistenceController.shared.syncStatus)
      reloadICloudSection()
      await observeAccountChanges()
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    iCloudStatusTask?.cancel()
    iCloudStatusTask = nil
  }

  /// Observes iCloud account changes while Settings is on screen, so the row updates reactively
  /// without requiring a dismiss / re-open. Watches both `CKAccountChanged` (CloudKit
  /// container sign-in/out) and `NSUbiquityIdentityDidChange` (iCloud identity token rotation,
  /// e.g. an account switch in Settings.app) since either can fire independently.
  private func observeAccountChanges() async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask { [weak self] in await self?.observeSingleNotification(.CKAccountChanged) }
      group.addTask { [weak self] in await self?.observeSingleNotification(.NSUbiquityIdentityDidChange) }
    }
  }

  private func observeSingleNotification(_ name: NSNotification.Name) async {
    let notifications = NotificationCenter.default.notifications(named: name)
    for await _ in notifications {
      await ICloudStatusLoader().load(into: PersistenceController.shared.syncStatus)
      reloadICloudSection()
    }
  }

  private func reloadICloudSection() {
    tableView.reloadSections(IndexSet(integer: iCloudSection), with: .none)
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
    2
  }

  override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case themesSection:
      return 3
    case iCloudSection:
      return 1
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
      return themeCell(tableView, at: indexPath)
    case iCloudSection:
      return iCloudCell(tableView, at: indexPath)
    case infoSection:
      return infoCell(tableView, at: indexPath)
    default:
      assertionFailure()
      return UITableViewCell()
    }
  }

  private func themeCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
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
  }

  private func iCloudCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "SyncStatusRow", for: indexPath) as? SyncStatusTableViewCell
    else { assertionFailure(); return UITableViewCell() }
    let statusText = iCloudStatusText
    cell.nameLabel.text = "iCloud Sync"
    cell.detailLabel.text = statusText
    // Read as one VoiceOver element ("iCloud Sync, iCloud Sync is Active") instead of two.
    cell.isAccessibilityElement = true
    cell.accessibilityLabel = "iCloud Sync, \(statusText)"
    return cell
  }

  private func infoCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "InfoRow", for: indexPath) as? InfoRowTableViewCell
    else { assertionFailure(); return UITableViewCell() }
    cell.iconImageView.image = UIImage(named: "PrivacyPolicyIcon25x25")
    cell.nameLabel.text = "Privacy Policy"
    return cell
  }

  /// The Settings iCloud row's status text, derived from `SyncStatus.rowState`.
  private var iCloudStatusText: String {
    switch PersistenceController.shared.syncStatus.rowState {
    case .checking:
      "Checking…"
    case .available:
      "iCloud Sync is Active"
    case .paused:
      "iCloud Sync Paused"
    case .unavailable:
      "iCloud Not Available"
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
    case iCloudSection:
      break // Display-only row; selectionStyle = .none, nothing to do on tap.
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
    case iCloudSection:
      "iCLOUD"
    case infoSection:
      "INFO"
    default:
      nil
    }
  }

  /// Footer copy is ported from budgets1's `SettingsView.swift` `iCloudSection` (with "budgets" ->
  /// "checklists", the only difference between the two apps' data), shown only for the two states
  /// where the user needs to do something or understand why sync isn't happening.
  override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
    switch section {
    case iCloudSection:
      switch PersistenceController.shared.syncStatus.rowState {
      case .unavailable:
        "Sign in to iCloud in Settings to sync your checklists across devices."
      case .paused:
        "Your checklists are saved on this device only. Restart the app to retry iCloud sync."
      case .checking, .available:
        nil
      }
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
