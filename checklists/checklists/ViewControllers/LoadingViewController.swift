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
  private lazy var stackView = UIStackView(arrangedSubviews: [activityIndicator, messageLabel, cloudSyncLabel])

  /// Reveals the note about iCloud. Set once the store's backing is known.
  var showsCloudSyncNote: Bool = false {
    didSet {
      cloudSyncLabel.isHidden = !showsCloudSyncNote
      updateAccessibility()
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
    messageLabel.font = .preferredFont(forTextStyle: .body)
    messageLabel.adjustsFontForContentSizeCategory = true
    messageLabel.textAlignment = .center
    messageLabel.numberOfLines = 0

    cloudSyncLabel.text = "Your checklists will now sync across your devices through iCloud."
    cloudSyncLabel.font = .preferredFont(forTextStyle: .footnote)
    cloudSyncLabel.adjustsFontForContentSizeCategory = true
    cloudSyncLabel.textColor = Colors.inactiveText
    cloudSyncLabel.textAlignment = .center
    cloudSyncLabel.numberOfLines = 0
    cloudSyncLabel.isHidden = !showsCloudSyncNote

    activityIndicator.color = Colors.teal
    activityIndicator.startAnimating()

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

    updateAccessibility()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Nothing else on screen is interactive, and the user did not ask for this screen to appear —
    // an explicit announcement is the only way VoiceOver users learn a migration is in progress
    // rather than assuming the app hung.
    UIAccessibility.post(notification: .screenChanged, argument: stackView)
  }

  /// Combines the visible labels into one announcement so VoiceOver reads the whole state in a
  /// single swipe rather than requiring the user to navigate between the spinner and each label.
  private func updateAccessibility() {
    stackView.isAccessibilityElement = true
    var label = messageLabel.text ?? ""
    if showsCloudSyncNote, let cloudSyncText = cloudSyncLabel.text {
      label += " " + cloudSyncText
    }
    stackView.accessibilityLabel = label
  }
}
