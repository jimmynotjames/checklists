//
//  ChecklistScreen.swift
//  checklists
//

import SwiftData
import SwiftUI
import UIKit

/// SwiftUI host for the still-UIKit `ChecklistViewController`, embedded in its own `UINavigationController` because it drives a real UIKit nav bar directly:
///   - its scroll handler animates `navigationItem.title` in and out past a threshold,
///   - it builds and changes its own trailing bar items, by mode and while a field is being typed into; see `ChecklistViewController.configureNavigationBar`.
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
  /// Bumped when a move out of this checklist's items finishes. The picker edits the store while
  /// the controller sits under it, and a sheet's dismissal gives a UIKit screen no appearance
  /// callback to reload on, so this is what tells it.
  @State private var transferGeneration = 0

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
      // The picker does the copying or moving itself and dismisses without navigating, so this and
      // `transferGeneration` are the whole of the host's involvement — see `CopyCheckedItemsView`.
      onRequestTransferCheckedItems: { id, mode in router.sheet = .transferCheckedItems(sourceID: id, mode: mode) },
      transferGeneration: transferGeneration
    )
    .onChange(of: router.sheet) { oldSheet, newSheet in
      // Matched before `checklist` is read: on the create sheet, Discard clears the sheet after
      // deleting the checklist. A cancelled move counts too: a reload of an unchanged list is
      // invisible.
      guard newSheet == nil, case let .transferCheckedItems(sourceID, .move) = oldSheet,
            sourceID == checklist.id else { return }
      transferGeneration += 1
    }
    // The view controller does its own keyboard avoidance via contentInset; opt out of SwiftUI's so
    // they don't stack.
    .ignoresSafeArea(.keyboard)
    // `.keyboard` narrows the ignored region, not the edges, so the hosted navigation controller is
    // still laid out inside the container safe area — leaving the strips above and below it showing
    // the presenting background rather than the table's own `Colors.defaultBackground`. Not a full
    // `ignoresSafeArea()`: giving the table real safe-area insets would shift `scrollViewDidScroll`'s
    // title threshold.
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
  let onRequestTransferCheckedItems: (String, CheckedItemsTransferMode) -> Void
  let transferGeneration: Int

  @Environment(\.analytics) private var analytics
  /// Named `modelContext` rather than `context`: `makeUIViewController(context:)` already binds
  /// that name.
  @Environment(\.modelContext) private var modelContext
  /// Optional on purpose: previews and tests build this screen without the app around it, and a
  /// missing coordinator should mean "no prompt", never a crash. `ChecklistsApp` always injects it.
  @Environment(RatingPromptCoordinator.self) private var ratingPrompt: RatingPromptCoordinator?
  /// Optional for the same reason as `ratingPrompt`.
  @Environment(ToastPresenter.self) private var toasts: ToastPresenter?

  func makeCoordinator() -> Coordinator {
    Coordinator(onRequestDismiss: onRequestDismiss, transferGeneration: transferGeneration)
  }

  func makeUIViewController(context: Context) -> UINavigationController {
    let viewController = ChecklistViewController()
    viewController.checklist = checklist
    viewController.context = modelContext
    viewController.isNewChecklist = isNewChecklist
    viewController.onRequestDismiss = onRequestDismiss
    viewController.onRequestOpenDuplicate = onRequestOpenDuplicate
    viewController.onRequestTransferCheckedItems = onRequestTransferCheckedItems
    viewController.onRemoteDeletion = { [toasts] in toasts?.show(.checklistDeletedElsewhere) }
    viewController.analytics = analytics
    viewController.ratingPrompt = ratingPrompt
    if !isNewChecklist {
      // The embedded navigation controller's root has no system back button, so recreate one.
      // Chevron-only, with no back title, is the intended look.
      let backButton = UIBarButtonItem(
        image: UIImage(systemName: "chevron.backward"),
        // Through the controller, so it knows it is leaving; see `hasRequestedDismissal`.
        primaryAction: UIAction { [weak viewController] _ in viewController?.requestDismissal() }
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
    let navigationController = ChecklistNavigationController(rootViewController: viewController)
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
    /// The last `transferGeneration` the controller was brought up to date with.
    var transferGeneration: Int

    init(onRequestDismiss: @escaping () -> Void, transferGeneration: Int) {
      self.onRequestDismiss = onRequestDismiss
      self.transferGeneration = transferGeneration
    }

    @objc func edgeSwipeBegan(_ gesture: UIScreenEdgePanGestureRecognizer) {
      guard gesture.state == .began else { return }
      // Through the controller when there is one, as the back button does.
      if let viewController {
        viewController.requestDismissal()
      } else {
        onRequestDismiss()
      }
    }

    /// Reorder Items mode hides the back button, and an edge swipe would be the way out it stands in for.
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
  func updateUIViewController(_ navigationController: UINavigationController, context: Context) {
    guard let viewController = navigationController.viewControllers.first as? ChecklistViewController else { return }
    assert(viewController.context === modelContext, "The screen's context changed under a live controller.")
    viewController.analytics = analytics
    viewController.ratingPrompt = ratingPrompt
    if context.coordinator.transferGeneration != transferGeneration {
      context.coordinator.transferGeneration = transferGeneration
      // The same refresh another device's edit gets, guards and all.
      viewController.handleRemoteChange()
    }
  }
}

/// The VoiceOver escape gesture runs up the responder chain from the focused element, and the nav
/// bar's chain reaches this controller without passing through its root. With focus on Reorder
/// Items mode's Done, escape would otherwise fall through to the SwiftUI stack and leave the screen.
private final class ChecklistNavigationController: UINavigationController {
  override func accessibilityPerformEscape() -> Bool {
    if let root = viewControllers.first as? ChecklistViewController, root.isReordering {
      return root.accessibilityPerformEscape()
    }
    return super.accessibilityPerformEscape()
  }
}

#if DEBUG
  // Between them these cover every text element on the screen; step through the canvas's Dynamic
  // Type sizes on each, and use the live preview to edit, enter Reorder Items mode, and scroll the
  // name into the navigation bar.

  #Preview("Existing checklist") {
    ChecklistScreen(checklist: PreviewSupport.checklist()) {}
      .previewEnvironment()
  }

  #Preview("Long name and notes") {
    ChecklistScreen(checklist: PreviewSupport.longContentChecklist()) {}
      .previewEnvironment(container: PreviewSupport.scratchContainer)
  }

  // Blank, so the name and notes placeholders show; no history caption on the create sheet.
  #Preview("New checklist") {
    ChecklistScreen(checklist: PreviewSupport.blankChecklist(), isNewChecklist: true) {}
      .previewEnvironment(container: PreviewSupport.scratchContainer)
  }

#endif
