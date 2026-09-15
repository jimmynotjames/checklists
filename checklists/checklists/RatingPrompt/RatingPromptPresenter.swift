//
//  RatingPromptPresenter.swift
//  checklists
//

import StoreKit
import SwiftUI

/// Root-level presenter for the automatic App Store review prompt.
///
/// Must be applied once, innermost on `RootView` in `ChecklistsApp` — misplaced, the app traps at
/// launch on the missing `Router` / `RatingPromptCoordinator` environment.
///
/// **Deferred past the transition**: the router flag flips at the *start* of a pop or dismiss
/// animation, and Apple's guidance is not to request mid-transition, so the gate is re-checked
/// after a short pause; anything that changes state in the meantime cancels the attempt.
///
/// No custom rating UI is presented, here or anywhere else.
private struct RatingPromptPresenter: ViewModifier {
  /// Long enough for the stack pop and sheet dismissal to settle; short enough that the person
  /// has not started anything new.
  static let settleDelay: Duration = .milliseconds(700)

  @Environment(\.requestReview) private var requestReview
  @Environment(\.scenePhase) private var scenePhase
  @Environment(RatingPromptCoordinator.self) private var coordinator
  @Environment(Router.self) private var router

  @State private var deferredRequest: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .onChange(of: coordinator.isRequestPending) { _, _ in scheduleIfReady() }
      .onChange(of: isOnChecklistsList) { _, _ in scheduleIfReady() }
      .onChange(of: scenePhase) { _, _ in scheduleIfReady() }
  }

  private var isOnChecklistsList: Bool {
    router.path.isEmpty && router.sheet == nil && !router.isMainMenuVisible
  }

  private var isReady: Bool {
    RatingPromptCoordinator.shouldRequestReview(
      isRequestPending: coordinator.isRequestPending,
      isOnChecklistsList: isOnChecklistsList,
      sceneIsActive: scenePhase == .active
    )
  }

  /// Every gating input change lands here, so an attempt that is no longer valid is cancelled
  /// and, if the new state qualifies, a fresh one is scheduled from now.
  private func scheduleIfReady() {
    deferredRequest?.cancel()
    deferredRequest = nil
    guard isReady else { return }
    deferredRequest = Task { @MainActor in
      try? await Task.sleep(for: Self.settleDelay)
      // `router` and `coordinator` are references, so this re-reads live state; `scenePhase` is
      // the value at scheduling time, but any change to it cancelled this task above.
      guard !Task.isCancelled, isReady else { return }
      requestReview()
      coordinator.consumePendingRequest()
    }
  }
}

extension View {
  /// Applies the automatic rating-prompt presenter. Apply once, innermost at the app root, so
  /// `Router` and `RatingPromptCoordinator` are ancestors in the environment.
  func ratingPromptPresenter() -> some View {
    modifier(RatingPromptPresenter())
  }
}
