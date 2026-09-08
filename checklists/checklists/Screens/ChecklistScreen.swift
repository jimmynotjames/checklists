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

  func makeCoordinator() -> Coordinator {
    Coordinator(onRequestDismiss: onRequestDismiss)
  }

  func makeUIViewController(context: Context) -> UINavigationController {
    let viewController = ChecklistViewController()
    viewController.checklist = checklist
    viewController.isNewChecklist = isNewChecklist
    viewController.onRequestDismiss = onRequestDismiss
    if !isNewChecklist {
      // The embedded navigation controller's root has no system back button, so recreate one.
      // Chevron-only, with no back title, is the intended look.
      let backButton = UIBarButtonItem(
        image: UIImage(systemName: "chevron.backward"),
        primaryAction: UIAction { _ in onRequestDismiss() }
      )
      // iOS 26 renders bar buttons in `labelColor` unless the item itself carries a tint.
      backButton.tintColor = .tintColor
      backButton.accessibilityLabel = "Back"
      viewController.navigationItem.leftBarButtonItem = backButton
    }
    let navigationController = UINavigationController(rootViewController: viewController)
    if !isNewChecklist {
      // Swipe-back: the embedded navigation controller swallows edge pans before they reach
      // SwiftUI's NavigationStack, and its own interactive-pop recognizer is inert with a
      // single view controller on its stack — so without this, the pop gesture is silently
      // dead. The pop itself still animates, driven by the router; only the finger-tracking
      // phase of the stock gesture is lost.
      let edgeSwipe = UIScreenEdgePanGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.edgeSwipeBegan(_:))
      )
      edgeSwipe.edges = .left
      navigationController.view.addGestureRecognizer(edgeSwipe)
    }
    return navigationController
  }

  @MainActor
  final class Coordinator: NSObject {
    private let onRequestDismiss: () -> Void

    init(onRequestDismiss: @escaping () -> Void) {
      self.onRequestDismiss = onRequestDismiss
    }

    @objc func edgeSwipeBegan(_ gesture: UIScreenEdgePanGestureRecognizer) {
      guard gesture.state == .began else { return }
      onRequestDismiss()
    }
  }

  /// Deliberately empty: ChecklistViewController documents that resetting `checklist` after
  /// viewDidLoad is undefined behavior, and the SwiftUI host never changes it in place.
  func updateUIViewController(_: UINavigationController, context _: Context) {}
}
