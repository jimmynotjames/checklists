//
//  RatingPromptPresenter.swift
//  checklists
//

import StoreKit
import SwiftUI

/// Root-level presenter for the automatic App Store review prompt.
///
/// Applied once, on `RootView`, where `Router` and `RatingPromptCoordinator` are both in the
/// environment. When the coordinator has a pending request, the scene is active, and the person
/// is on the checklists list — nothing pushed, no sheet, main menu closed — it calls the native
/// `requestReview` and lets the coordinator record that. Watching the router is what makes the
/// prompt land *after* the checklist screen is popped (or the new-checklist sheet dismissed)
/// rather than over it; StoreKit then decides whether a dialog actually appears.
///
/// No custom rating UI is presented, here or anywhere else.
private struct RatingPromptPresenter: ViewModifier {
  @Environment(\.requestReview) private var requestReview
  @Environment(\.scenePhase) private var scenePhase
  @Environment(RatingPromptCoordinator.self) private var coordinator
  @Environment(Router.self) private var router

  func body(content: Content) -> some View {
    content
      .onChange(of: coordinator.isRequestPending) { _, _ in presentIfReady() }
      .onChange(of: isOnChecklistsList) { _, _ in presentIfReady() }
      .onChange(of: scenePhase) { _, _ in presentIfReady() }
  }

  private var isOnChecklistsList: Bool {
    router.path.isEmpty && router.sheet == nil && !router.isMainMenuVisible
  }

  private func presentIfReady() {
    guard RatingPromptCoordinator.shouldRequestReview(
      isRequestPending: coordinator.isRequestPending,
      isOnChecklistsList: isOnChecklistsList,
      sceneIsActive: scenePhase == .active
    ) else { return }
    requestReview()
    coordinator.consumePendingRequest()
  }
}

extension View {
  /// Applies the automatic rating-prompt presenter. Apply once at the app root, where `Router`
  /// and `RatingPromptCoordinator` are in the environment.
  func ratingPromptPresenter() -> some View {
    modifier(RatingPromptPresenter())
  }
}
