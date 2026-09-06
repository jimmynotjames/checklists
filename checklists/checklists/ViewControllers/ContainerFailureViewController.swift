//
//  ContainerFailureViewController.swift
//  checklists
//

import UIKit

/**
 Shown when the store cannot be opened, or the one-time Realm copy cannot be completed.

 Shown rather than continuing into an empty checklist list, because to an upgrading user an empty
 list is indistinguishable from having lost everything. Nothing has been deleted at this point —
 the store simply would not open, and on the one launch that migrates, the old Realm file is still
 untouched on disk — so relaunching is a real chance of recovery.

 There is deliberately no Retry button. It re-ran the same startup sequence in the same process,
 which is what relaunching does anyway and more thoroughly, so it offered a second path to the same
 outcome while the copy was already telling the user to restart.

 The error code is not shown on screen (nobody acts on "134060"); it travels in the feedback mail
 body instead, where it is useful. Only the error's domain and code go in, never its description,
 which can carry the user's own content.
 */
protocol ContainerFailureViewControllerDelegate: AnyObject {
  /// The user confirmed "Start over fresh". Every local store has already been deleted; the
  /// delegate is responsible for re-running startup.
  func containerFailureViewControllerDidResetStore(_ controller: ContainerFailureViewController)
}

final class ContainerFailureViewController: UIViewController {
  weak var delegate: ContainerFailureViewControllerDelegate?

  private let failure: ContainerCreationFailure

  init(failure: ContainerCreationFailure) {
    self.failure = failure
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("This init() not supported.")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = Colors.defaultBackground

    let iconView = UIImageView(image: UIImage(systemName: "externaldrive.badge.exclamationmark"))
    iconView.contentMode = .scaleAspectFit
    iconView.tintColor = Colors.inactiveText
    iconView.isAccessibilityElement = false
    iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44.0, weight: .regular)

    let titleLabel = UILabel()
    titleLabel.text = "Couldn't open your checklists"
    titleLabel.font = .boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .title2).pointSize)
    titleLabel.adjustsFontForContentSizeCategory = true
    titleLabel.textAlignment = .center
    titleLabel.numberOfLines = 0

    let bodyLabel = UILabel()
    bodyLabel.text = "Something went wrong. Try restarting the app? Also check if your storage is full?"
    bodyLabel.font = .preferredFont(forTextStyle: .body)
    bodyLabel.adjustsFontForContentSizeCategory = true
    bodyLabel.textAlignment = .center
    bodyLabel.numberOfLines = 0

    let messageStackView = UIStackView(arrangedSubviews: [iconView, titleLabel, bodyLabel])
    messageStackView.axis = .vertical
    messageStackView.alignment = .center
    messageStackView.spacing = 12.0
    messageStackView.isAccessibilityElement = true
    messageStackView.accessibilityLabel = "\(titleLabel.text ?? ""). \(bodyLabel.text ?? "")"

    let feedbackButton = CLButton(frame: .zero)
    feedbackButton.setTitle("Send Feedback", for: .normal)
    feedbackButton.addTarget(self, action: #selector(sendFeedbackTapped), for: .touchUpInside)
    feedbackButton.accessibilityLabel = "Send Feedback"
    feedbackButton.accessibilityHint = "Opens an email with the error details. No personal data is included."

    let startOverButton = CLButton(frame: .zero)
    startOverButton.setTitle("Start over fresh", for: .normal)
    startOverButton.configuration?.baseForegroundColor = Colors.salmonRed
    startOverButton.addTarget(self, action: #selector(startOverTapped), for: .touchUpInside)
    startOverButton.accessibilityLabel = "Start over fresh"
    startOverButton.accessibilityHint = "Deletes the checklists stored on this device and starts the app as if it were newly installed."

    let buttonStackView = UIStackView(arrangedSubviews: [feedbackButton, startOverButton])
    buttonStackView.axis = .vertical
    buttonStackView.alignment = .fill
    buttonStackView.spacing = 12.0

    let stackView = UIStackView(arrangedSubviews: [messageStackView, buttonStackView])
    stackView.axis = .vertical
    stackView.alignment = .fill
    stackView.spacing = 32.0
    stackView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stackView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
    ])
  }

  @objc private func startOverTapped() {
    // Destructive and irreversible, on a screen the user reaches while already alarmed — so it
    // confirms first, and the confirmation says plainly what is lost rather than "are you sure?".
    let alert = UIAlertController(
      title: "Start over fresh?",
      message: "This deletes the checklists stored on this device and starts the app as if it were newly installed. This cannot be undone.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete and Start Over", style: .destructive) { [weak self] _ in
      guard let self else { return }
      AnalyticsManager.logStartupStoreReset()
      StoreReset.startOverFresh()
      delegate?.containerFailureViewControllerDidResetStore(self)
    })
    present(alert, animated: true)
  }

  @objc private func sendFeedbackTapped() {
    AnalyticsManager.logSendFeedback()

    var components = URLComponents()
    components.scheme = "mailto"
    components.path = "jimmyho.appfeedback@gmail.com"
    components.queryItems = [
      URLQueryItem(name: "subject", value: "Checklists data error"),
      URLQueryItem(name: "body", value: "Error: \(failure.diagnosticDescription)"),
    ]
    guard let url = components.url else { assertionFailure(); return }
    UIApplication.shared.open(url)
  }
}
