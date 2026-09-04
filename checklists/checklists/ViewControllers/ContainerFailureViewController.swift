//
//  ContainerFailureViewController.swift
//  checklists
//

import UIKit

protocol ContainerFailureViewControllerDelegate: AnyObject {
  func containerFailureViewControllerDidTapRetry(_ controller: ContainerFailureViewController)
}

/**
 Shown when the store cannot be opened, or the one-time Realm copy cannot be completed.

 Deliberately offers Retry rather than continuing into an empty checklist list: for an upgrading
 user, an empty list is indistinguishable from having lost everything. Nothing has been deleted at
 this point — the Realm file is still on disk — so a retry on the next launch is a real chance of
 recovery.

 The error code is not shown on screen (nobody acts on "134060"); it travels in the feedback mail
 body instead, where it is useful. Only the error's domain and code go in, never its description,
 which can carry the user's own content.
 */
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

    let titleLabel = UILabel()
    titleLabel.text = "Couldn't open your checklists"
    titleLabel.textAlignment = .center
    titleLabel.numberOfLines = 0

    let bodyLabel = UILabel()
    bodyLabel.text = "Something went wrong opening the app's data. Restarting usually fixes it."
    bodyLabel.textAlignment = .center
    bodyLabel.numberOfLines = 0

    let retryButton = CLButton(frame: .zero)
    retryButton.setTitle("Retry", for: .normal)
    retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

    let feedbackButton = CLButton(frame: .zero)
    feedbackButton.setTitle("Send Feedback", for: .normal)
    feedbackButton.addTarget(self, action: #selector(sendFeedbackTapped), for: .touchUpInside)

    let stackView = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, retryButton, feedbackButton])
    stackView.axis = .vertical
    stackView.alignment = .center
    stackView.spacing = 16.0
    stackView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stackView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
    ])
  }

  @objc private func retryTapped() {
    delegate?.containerFailureViewControllerDidTapRetry(self)
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
