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
    guard let mainMenuViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "MainMenu") as? MainMenuTableViewController else { assertionFailure(); return }
    mainMenuViewController.delegate = self

    let navigationController = UINavigationController(rootViewController: mainMenuViewController)
    navigationController.modalTransitionStyle = mainMenuViewController.modalTransitionStyle
    navigationController.modalPresentationStyle = mainMenuViewController.modalPresentationStyle
    navigationController.transitioningDelegate = mainMenuViewController

    navigationController.navigationBar.barTintColor = CLUIColors.darkBlueGray
    navigationController.navigationBar.tintColor = CLUIColors.defaultBackground

    present(navigationController, animated: true)
  }
}

protocol MainMenuTableViewControllerDelegate: AnyObject {
  func openSettingsPage()
  func openDonatePage()
}

class MainMenuTableViewController: UITableViewController {

  static private let numberOfRows = 4

  weak var delegate: MainMenuTableViewControllerDelegate?

  var preferredHeight: CGFloat = {
    return CGFloat(numberOfRows) * 44.0 + 18.0
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.contentInset = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 0.0, right: 0.0)

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

  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return MainMenuTableViewController.numberOfRows
  }

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 60.0
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "navigationMenuItem", for: indexPath)

    guard
      let imageView: UIImageView = cell.viewWithTag(101) as? UIImageView,
      let label: UILabel = cell.viewWithTag(102) as? UILabel
      else { assertionFailure(); return cell }
    switch indexPath.row {
    case 0:
      label.text = "Feedback"
      imageView.image = UIImage(named: "MainMenuFeedbackIcon")
    case 1:
      label.text = "Rate in App Store"
      imageView.image = UIImage(named: "MainMenuRateInAppStoreIcon")
    case 2:
      label.text = "Donate!"
      imageView.image = UIImage(named: "MainMenuDonateIcon")
    case 3:
      label.text = "Settings"
      imageView.image = UIImage(named: "MainMenuSettingsIcon")
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
        self.delegate?.openDonatePage()
      }
    case 3:
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
  func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return MainMenuTransitionAnimator(type: .presenting)
  }

  func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
    return MainMenuTransitionAnimator(type: .dismissing)
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

  func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
    return 0.2
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
