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
///
/// The wrapper exists so the safe-area handling below travels with the screen instead of being
/// restated at each presentation site.
struct ChecklistScreen: View {
  let checklist: Checklist
  var isNewChecklist = false
  /// Routes every way of leaving the screen (Done, back, remote deletion) through the SwiftUI
  /// router so navigation state can't desync from what's on screen.
  let onRequestDismiss: () -> Void

  @Environment(Router.self) private var router
  @Environment(AnalyticsSettings.self) private var settings

  var body: some View {
    ChecklistControllerView(
      checklist: checklist,
      isNewChecklist: isNewChecklist,
      onRequestDismiss: onRequestDismiss
    )
    // The view controller does its own keyboard avoidance via contentInset (the reason it ditched
    // UITableViewController); opt out of SwiftUI's so they don't stack.
    .ignoresSafeArea(.keyboard)
    // `.keyboard` narrows the ignored region, not the edges, so the hosted navigation controller is
    // still laid out inside the container safe area — leaving the strips above and below it showing
    // the presenting background rather than the table's own `Colors.defaultBackground`. Not a full
    // `ignoresSafeArea()`: giving the table real safe-area insets would shift `scrollViewDidScroll`'s
    // hardcoded title threshold and `scrollToTop()`'s `contentOffset.y == 0` assumptions.
    .background(Colors.defaultBackgroundColor.ignoresSafeArea())
    // First-run consent trigger (core-docs/analytics-spec.md §6.2): the moment right before
    // `checklist_name` could first be transmitted. `isNewChecklist` is load-bearing — in the
    // `.newChecklist` route this view *is* the presented sheet, so presenting the consent sheet
    // there would replace the sheet the person is already looking at.
    .task {
      guard !isNewChecklist else { return }
      guard ConsentJurisdiction.kind(for: Locale.current.region?.identifier) == .required,
            !settings.analyticsOptInExplicitlySet else { return }
      router.sheet = .analyticsConsent
    }
  }
}

private struct ChecklistControllerView: UIViewControllerRepresentable {
  let checklist: Checklist
  let isNewChecklist: Bool
  let onRequestDismiss: () -> Void

  @Environment(\.analytics) private var analytics
  /// Optional on purpose: previews and tests build this screen without the app around it, and a
  /// missing coordinator should mean "no prompt", never a crash. `ChecklistsApp` always injects it.
  @Environment(RatingPromptCoordinator.self) private var ratingPrompt: RatingPromptCoordinator?

  func makeCoordinator() -> Coordinator {
    Coordinator(onRequestDismiss: onRequestDismiss)
  }

  func makeUIViewController(context: Context) -> UINavigationController {
    let viewController = ChecklistViewController()
    viewController.checklist = checklist
    viewController.isNewChecklist = isNewChecklist
    viewController.onRequestDismiss = onRequestDismiss
    viewController.analytics = analytics
    viewController.ratingPrompt = ratingPrompt
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

  /// The checklist itself is deliberately not re-applied: ChecklistViewController documents that
  /// resetting `checklist` after viewDidLoad is undefined behavior, and the SwiftUI host never
  /// changes it in place.
  ///
  /// The analytics client *is* re-applied. It never changes today — one process-wide instance —
  /// but if a future change swaps the client rather than gating inside it, a checklist already on
  /// screen would otherwise keep sending through the old one.
  func updateUIViewController(_ navigationController: UINavigationController, context _: Context) {
    guard let viewController = navigationController.viewControllers.first as? ChecklistViewController else { return }
    viewController.analytics = analytics
    viewController.ratingPrompt = ratingPrompt
  }
}

#if DEBUG
  #Preview("Existing checklist") {
    ChecklistScreen(checklist: PreviewSupport.checklist()) {}
      .previewEnvironment()
  }

  #Preview("New checklist") {
    ChecklistScreen(checklist: PreviewSupport.checklist(), isNewChecklist: true) {}
      .previewEnvironment()
  }
#endif
