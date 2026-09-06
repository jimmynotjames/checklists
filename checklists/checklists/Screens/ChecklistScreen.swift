//
//  ChecklistScreen.swift
//  checklists
//

import SwiftUI
import UIKit

/// SwiftUI host for the still-UIKit `ChecklistViewController` (the checklist-detail screen).
///
/// The view controller is deliberately not converted yet, and it is embedded in its own
/// `UINavigationController` rather than bridged onto SwiftUI's toolbar because it leans on
/// having a real UIKit navigation bar it can drive directly:
///   - its scroll handler animates `navigationItem.title` in and out past a threshold,
///   - it swaps `navigationItem.rightBarButtonItem` (Done vs. Reset) based on `isNewChecklist`,
///   - the UI tests address `navigationBars["checklists.ChecklistView"]` and its buttons.
/// When pushed, the caller hides SwiftUI's navigation bar for this destination so only the
/// embedded bar shows.
struct ChecklistScreen: UIViewControllerRepresentable {
  let checklist: Checklist
  var isNewChecklist = false
  /// Routes every way of leaving the screen (Done, back, remote deletion) through the SwiftUI
  /// router so navigation state can't desync from what's on screen.
  let onRequestDismiss: () -> Void

  func makeUIViewController(context _: Context) -> UINavigationController {
    let viewController = ChecklistViewController()
    viewController.checklist = checklist
    viewController.isNewChecklist = isNewChecklist
    viewController.onRequestDismiss = onRequestDismiss
    if !isNewChecklist {
      // The embedded navigation controller's root has no system back button, so recreate one.
      // Chevron-only matches the old look: the pushing screen used to blank the back title
      // by setting `backBarButtonItem` to " ".
      let backButton = UIBarButtonItem(
        image: UIImage(systemName: "chevron.backward"),
        primaryAction: UIAction { _ in onRequestDismiss() }
      )
      backButton.accessibilityLabel = "Back"
      viewController.navigationItem.leftBarButtonItem = backButton
    }
    return UINavigationController(rootViewController: viewController)
  }

  /// Deliberately empty: ChecklistViewController documents that resetting `checklist` after
  /// viewDidLoad is undefined behavior, and the SwiftUI host never changes it in place.
  func updateUIViewController(_: UINavigationController, context _: Context) {}
}
