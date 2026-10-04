//
//  ChecklistScreen.swift
//  checklists
//

import SwiftData
import SwiftUI
import UIKit

/// SwiftUI host for the still-UIKit `ChecklistViewController`, embedded in its own `UINavigationController` because it drives a real UIKit nav bar directly:
///   - its scroll handler animates `navigationItem.title` in and out past a threshold,
///   - it swaps the trailing bar items based on `isNewChecklist` (Done plus an overflow menu holding only Discard on the create sheet; Reset plus the full menu otherwise).
/// When pushed, the caller hides SwiftUI's navigation bar for this destination so only the
/// embedded bar shows.
///
/// The wrapper exists so the safe-area handling below travels with the screen instead of being restated at each presentation site.
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
      onRequestDismiss: onRequestDismiss,
      // A duplicate opens in the create sheet, not as a push: like `ChecklistsView.addChecklist`'s
      // row, it exists in the store but has not been kept yet. Everything the sheet does about that
      // is what a copy wants — Done instead of Reset, the name field focused for renaming, no
      // history caption, and Discard as the way to undo an accidental duplicate.
      onRequestOpenDuplicate: { id in router.sheet = .newChecklist(id: id) },
      // The picker does the copying itself and dismisses without navigating, so this is the whole
      // of the host's involvement — see `CopyCheckedItemsView`.
      onRequestCopyCheckedItems: { id in router.sheet = .copyCheckedItems(sourceID: id) }
    )
    // The view controller does its own keyboard avoidance via contentInset; opt out of SwiftUI's so
    // they don't stack.
    .ignoresSafeArea(.keyboard)
    // `.keyboard` narrows the ignored region, not the edges, so the hosted navigation controller is
    // still laid out inside the container safe area — leaving the strips above and below it showing
    // the presenting background rather than the table's own `Colors.defaultBackground`. Not a full
    // `ignoresSafeArea()`: giving the table real safe-area insets would shift `scrollViewDidScroll`'s
    // hardcoded title threshold.
    .background(Colors.defaultBackgroundColor.ignoresSafeArea())
    // First-run consent trigger (`analytics-spec.md §Strict-opt-in jurisdictions`): the moment
    // right before `checklist_name` could first be transmitted. `isNewChecklist` is load-bearing —
    // in the `.newChecklist` route this view *is* the presented sheet, so presenting the consent
    // sheet there would replace the sheet the person is already looking at.
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
  let onRequestOpenDuplicate: (String) -> Void
  let onRequestCopyCheckedItems: (String) -> Void

  @Environment(\.analytics) private var analytics
  /// Named `modelContext` rather than `context`: `makeUIViewController(context:)` already binds
  /// that name.
  @Environment(\.modelContext) private var modelContext
  /// Optional on purpose: previews and tests build this screen without the app around it, and a
  /// missing coordinator should mean "no prompt", never a crash. `ChecklistsApp` always injects it.
  @Environment(RatingPromptCoordinator.self) private var ratingPrompt: RatingPromptCoordinator?

  func makeCoordinator() -> Coordinator {
    Coordinator(onRequestDismiss: onRequestDismiss)
  }

  func makeUIViewController(context: Context) -> UINavigationController {
    let viewController = ChecklistViewController()
    viewController.checklist = checklist
    viewController.context = modelContext
    viewController.isNewChecklist = isNewChecklist
    viewController.onRequestDismiss = onRequestDismiss
    viewController.onRequestOpenDuplicate = onRequestOpenDuplicate
    viewController.onRequestCopyCheckedItems = onRequestCopyCheckedItems
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
      backButton.accessibilityLabel = String(
        localized: "checklist.back.accessibilityLabel",
        defaultValue: "Back",
        comment: "VoiceOver label for the chevron-only back button on the checklist detail screen."
      )
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
      edgeSwipe.delegate = context.coordinator
      context.coordinator.viewController = viewController
      navigationController.view.addGestureRecognizer(edgeSwipe)
    }
    return navigationController
  }

  @MainActor
  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    private let onRequestDismiss: () -> Void
    weak var viewController: ChecklistViewController?

    init(onRequestDismiss: @escaping () -> Void) {
      self.onRequestDismiss = onRequestDismiss
    }

    @objc func edgeSwipeBegan(_ gesture: UIScreenEdgePanGestureRecognizer) {
      guard gesture.state == .began else { return }
      onRequestDismiss()
    }

    /// Reorder Items mode hides the back button, and an edge swipe would be a way out that skips it.
    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
      viewController?.isReordering != true
    }
  }

  /// `checklist` and `context` are set once, before `viewDidLoad`, and never re-applied: the
  /// controller's remote-change observer and any rows it inserted belong to that context, and so
  /// does `checklist`. A new container can only arrive across `ChecklistsApp`'s `.ready`/`.failed`
  /// switch, which rebuilds this view anyway; the assertion is the tripwire if that stops being
  /// true. The analytics client and rating-prompt coordinator are re-applied so a swapped instance
  /// never leaves a screen on the old one.
  func updateUIViewController(_ navigationController: UINavigationController, context _: Context) {
    guard let viewController = navigationController.viewControllers.first as? ChecklistViewController else { return }
    assert(viewController.context === modelContext, "The screen's context changed under a live controller.")
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

  // Live mode: ⋯ > Reorder Items, then drag the handles and tap Done.
  #Preview("Reorder Items") {
    ChecklistScreen(checklist: PreviewSupport.checklist(id: SampleData.preTripId)) {}
      .previewEnvironment()
  }
#endif
