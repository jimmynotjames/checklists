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
final class ContainerFailureViewController: UIViewController {
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
    bodyLabel.text = "Something went wrong. Try restarting the app?"
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

    let buttonStackView = UIStackView(arrangedSubviews: [feedbackButton])
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
