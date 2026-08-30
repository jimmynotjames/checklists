//
//  MainMenuTableViewController.swift
//  checklists
//
//  Created by Jimmy Ho on 7/28/19.
//  Copyright © 2019 Jimmy Ho. All rights reserved.
//

import UIKit

protocol MainMenuEnabledViewController {
  func presentMainMenuModal()
}

extension MainMenuEnabledViewController where Self: UIViewController, Self: MainMenuTableViewControllerDelegate {
  func presentMainMenuModal() {
    let mainMenuViewController = MainMenuTableViewController(style: .plain)
    mainMenuViewController.modalPresentationStyle = .fullScreen
    mainMenuViewController.delegate = self

    let navigationController = UINavigationController(rootViewController: mainMenuViewController)
    navigationController.modalTransitionStyle = mainMenuViewController.modalTransitionStyle
    navigationController.modalPresentationStyle = mainMenuViewController.modalPresentationStyle
    navigationController.transitioningDelegate = mainMenuViewController

    navigationController.navigationBar.barTintColor = Colors.darkBlueGray
    navigationController.navigationBar.tintColor = Colors.defaultBackground

    present(navigationController, animated: true)
  }
}

protocol MainMenuTableViewControllerDelegate: AnyObject {
  func openSettingsPage()
}

class MainMenuTableViewController: UITableViewController {
  private static let numberOfRows = 3

  weak var delegate: MainMenuTableViewControllerDelegate?

  var preferredHeight: CGFloat = .init(numberOfRows) * 44.0 + 18.0

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.contentInset = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 0.0, right: 0.0)

    tableView.backgroundColor = Colors.darkBlueGray
    tableView.separatorStyle = .none
    tableView.sectionHeaderHeight = 28
    tableView.sectionFooterHeight = 28
    tableView.register(MainMenuItemTableViewCell.self, forCellReuseIdentifier: "navigationMenuItem")

    navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "StopIcon"), style: .plain, target: self, action: #selector(dismissButtonTapped))
    navigationItem.leftBarButtonItem?.accessibilityLabel = "Close menu"
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    AnalyticsManager.logMainMenuViewed()
  }

  @objc func dismissButtonTapped() {
    dismiss(animated: true, completion: nil)
  }

  // MARK: - Table view data source

  override func numberOfSections(in _: UITableView) -> Int {
    1
  }

  override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
    MainMenuTableViewController.numberOfRows
  }

  override func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
    60.0
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let cell = tableView.dequeueReusableCell(withIdentifier: "navigationMenuItem", for: indexPath) as? MainMenuItemTableViewCell
    else { assertionFailure(); return UITableViewCell() }

    switch indexPath.row {
    case 0:
      cell.titleLabel.text = "Feedback"
      cell.iconImageView.image = UIImage(named: "MainMenuFeedbackIcon")
    case 1:
      cell.titleLabel.text = "Rate in App Store"
      cell.iconImageView.image = UIImage(named: "MainMenuRateInAppStoreIcon")
    case 2:
      cell.titleLabel.text = "Settings"
      cell.iconImageView.image = UIImage(named: "MainMenuSettingsIcon")
    default:
      assertionFailure()
    }
    cell.selectionStyle = .none
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    switch indexPath.row {
    case 0:
      AnalyticsManager.logSendFeedback()
      guard let url = URL(string: "mailto:jimmyho.appfeedback@gmail.com?subject=Feedback%20for%20reChecklist%20App") else { assertionFailure(); return }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    case 1:
      AnalyticsManager.logRateInAppStore()
      guard let url = URL(string: "https://itunes.apple.com/app/id1475724536?action=write-review") else { assertionFailure(); return }
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    case 2:
      dismiss(animated: false) {
        self.delegate?.openSettingsPage()
      }
    default:
      assertionFailure()
    }
    tableView.cellForRow(at: indexPath)?.isSelected = false
  }
}

extension MainMenuTableViewController: UIViewControllerTransitioningDelegate {
  func animationController(forPresented _: UIViewController, presenting _: UIViewController, source _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    MainMenuTransitionAnimator(type: .presenting)
  }

  func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    MainMenuTransitionAnimator(type: .dismissing)
  }
}

class MainMenuTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  enum TransitionType {
    case presenting
    case dismissing
  }

  let type: TransitionType

  required init(type: TransitionType) {
    self.type = type
    super.init()
  }

  func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
    0.2
  }

  func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    guard let toViewController = transitionContext.viewController(forKey: .to) else { return }
    guard let toView = transitionContext.view(forKey: .to) else { return }
    transitionContext.containerView.addSubview(toView)

    /*
     If we're presenting, then move the frame to the left, so it whooshes in to the right.
     If we're dismissing, then place the underlying view controller to the right so it whooshes left,
     giving the effect that the menu is collapsing.
     */
    let finalFrame = transitionContext.finalFrame(for: toViewController)
    var toViewFrame = toView.frame
    toViewFrame.origin.x = finalFrame.origin.x
    switch type {
    case .presenting:
      toViewFrame.origin.x -= finalFrame.size.width
    case .dismissing:
      toViewFrame.origin.x += finalFrame.size.width
    }
    toView.frame = toViewFrame

    UIView.animate(withDuration: 0.2, animations: {
      toView.frame = finalFrame
    }, completion: { success in
      if success {
        transitionContext.completeTransition(true)
      }
    })
  }
}
