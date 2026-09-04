//
//  LoadingViewController.swift
//  checklists
//

import UIKit

/// Shown while the one-time copy out of the old Realm store runs.
///
/// Only ever appears on the single launch after an upgrade from a Realm build. Every other launch
/// installs the checklist list directly, exactly as before.
final class LoadingViewController: UIViewController {
  private let activityIndicator = UIActivityIndicatorView(style: .large)
  private let messageLabel = UILabel()
  private let cloudSyncLabel = UILabel()

  /// Reveals the note about iCloud. Set once the store's backing is known.
  var showsCloudSyncNote: Bool = false {
    didSet {
      cloudSyncLabel.isHidden = !showsCloudSyncNote
    }
  }

  init(showsCloudSyncNote: Bool = false) {
    self.showsCloudSyncNote = showsCloudSyncNote
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("This init() not supported.")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = Colors.defaultBackground

    messageLabel.text = "Migrating databases… need a moment…"
    messageLabel.textAlignment = .center
    messageLabel.numberOfLines = 0

    cloudSyncLabel.text = "Your checklists will now sync across your devices through iCloud."
    cloudSyncLabel.textAlignment = .center
    cloudSyncLabel.numberOfLines = 0
    cloudSyncLabel.isHidden = !showsCloudSyncNote

    activityIndicator.startAnimating()

    let stackView = UIStackView(arrangedSubviews: [activityIndicator, messageLabel, cloudSyncLabel])
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.spacing = 16.0
    stackView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
      stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),
    ])
  }
}
