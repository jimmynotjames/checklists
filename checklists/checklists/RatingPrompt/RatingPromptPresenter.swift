//
//  RatingPromptPresenter.swift
//  checklists
//

import StoreKit
import SwiftUI

/// Root-level presenter for the automatic App Store review prompt.
///
/// **Between tasks**: with no sheet up, either no checklist is open, or one has just been left for
/// another. The second only happens on a wide window, where ChecklistsView sits beside the open
/// checklist and picking another row moves on without ever closing one; it counts once, for the
/// attempt it starts, so a request that becomes pending later, mid-checklist, still waits.
///
/// **Deferred past the transition**: the router flips at the *start* of a pop, dismiss or switch,
/// and Apple's guidance is not to request mid-transition, so the gate is re-checked after a short
/// pause; anything that changes state in the meantime cancels the attempt.
///
/// No custom rating UI is presented, here or anywhere else.
private struct RatingPromptPresenter: ViewModifier {
  /// Long enough for a pop, a switch of checklist, or a sheet dismissal to settle; short enough that the person
  /// has not started anything new.
  static let settleDelay: Duration = .milliseconds(700)

  @Environment(\.requestReview) private var requestReview
  @Environment(\.scenePhase) private var scenePhase
  @Environment(RatingPromptCoordinator.self) private var coordinator
  @Environment(Router.self) private var router

  @State private var deferredRequest: Task<Void, Never>?
  /// Set when the open checklist is left; cleared once the attempt it starts has run, or at once if
  /// it starts none.
  @State private var hasJustLeftChecklist = false

  func body(content: Content) -> some View {
    content
      .onChange(of: coordinator.isRequestPending) { _, _ in scheduleIfReady() }
      .onChange(of: router.selectedChecklistID) { left, _ in
        hasJustLeftChecklist = left != nil
        scheduleIfReady()
      }
      .onChange(of: router.sheet) { _, _ in scheduleIfReady() }
      .onChange(of: scenePhase) { _, _ in scheduleIfReady() }
  }

  private var isBetweenTasks: Bool {
    RatingPromptCoordinator.isBetweenTasks(
      isChecklistOpen: router.selectedChecklistID != nil,
      hasJustLeftChecklist: hasJustLeftChecklist,
      isSheetUp: router.sheet != nil,
    )
  }

  private var isReady: Bool {
    RatingPromptCoordinator.shouldRequestReview(
      isRequestPending: coordinator.isRequestPending,
      isBetweenTasks: isBetweenTasks,
      sceneIsActive: scenePhase == .active,
    )
  }

  /// Every gating input change lands here, so an attempt that is no longer valid is cancelled
  /// and, if the new state qualifies, a fresh one is scheduled from now.
  private func scheduleIfReady() {
    deferredRequest?.cancel()
    deferredRequest = nil
    guard isReady else {
      hasJustLeftChecklist = false
      return
    }
    deferredRequest = Task { @MainActor in
      try? await Task.sleep(for: Self.settleDelay)
      // Cancelled means a newer attempt has taken over, and the mark with it.
      guard !Task.isCancelled else { return }
      // `router` and `coordinator` are references, so this re-reads live state; `scenePhase` is
      // the value at scheduling time, but any change to it cancelled this task above.
      let isStillReady = isReady
      hasJustLeftChecklist = false
      guard isStillReady else { return }
      requestReview()
      coordinator.consumePendingRequest()
    }
  }
}

extension View {
  /// Applies the automatic rating-prompt presenter. Apply once, innermost on `RootView` in
  /// `ChecklistsApp`, or the app traps at launch on the missing `Router` / coordinator.
  func ratingPromptPresenter() -> some View {
    modifier(RatingPromptPresenter())
  }
}
