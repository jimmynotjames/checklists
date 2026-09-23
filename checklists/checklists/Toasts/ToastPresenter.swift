//
//  ToastPresenter.swift
//  checklists
//

import SwiftUI
import UIKit

/**
 Holds the toast currently on screen and retires it on time.

 Newest wins: an arriving toast replaces whatever is up, immediately. Nothing is queued or merged,
 so no toast's contents are quietly discarded in favour of the one already showing.

 The dismissal timer lives here rather than in `ToastLayer`'s `@State` because a toast is raised
 from arbitrary call sites, which view state cannot reach, and a re-instantiated modifier would
 orphan it. Sleeping and the VoiceOver check are injectable so the lifecycle tests need no clock.
 */
@Observable
@MainActor
final class ToastPresenter {
  /// How long an action toast stays up. Long enough to read the message, reach the button and
  /// tap it; the default dwell is not.
  ///
  /// `nonisolated` so the policy function below can read it.
  nonisolated static let actionDisplayDuration: Duration = .seconds(5)

  private(set) var current: Toast?

  private let autoDismissDelay: Duration
  private let isVoiceOverRunning: @MainActor () -> Bool
  private let sleep: @Sendable (Duration) async -> Void

  /// The one scheduled dismissal, and the only thing this slot holds: a second job would let one
  /// arriving toast cancel another on its way to the screen.
  @ObservationIgnored private var dismissal: Task<Void, Never>?

  /// - Parameter sleep: the delay mechanism. Injected so tests drive the lifecycle without
  ///   wall-clock waits.
  init(
    autoDismissDelay: Duration = .seconds(2),
    isVoiceOverRunning: @escaping @MainActor () -> Bool = { UIAccessibility.isVoiceOverRunning },
    sleep: @escaping @Sendable (Duration) async -> Void = { try? await Task.sleep(for: $0) }
  ) {
    self.autoDismissDelay = autoDismissDelay
    self.isVoiceOverRunning = isVoiceOverRunning
    self.sleep = sleep
  }

  // MARK: - Showing

  func show(_ toast: Toast) {
    current = toast
    scheduleDismissal(of: toast)
  }

  func dismiss() {
    dismissal?.cancel()
    dismissal = nil
    current = nil
  }

  private func scheduleDismissal(of toast: Toast) {
    dismissal?.cancel()
    guard let delay = Self.displayDuration(
      for: toast,
      base: autoDismissDelay,
      isVoiceOverRunning: isVoiceOverRunning()
    ) else {
      dismissal = nil
      return
    }
    dismissal = Task { @MainActor [weak self, sleep] in
      await sleep(delay)
      // The id check keeps the invariant local: `Task.isCancelled` alone relies on every caller
      // cancelling this slot before changing `current`.
      guard !Task.isCancelled, let self, current?.id == toast.id else { return }
      dismiss()
    }
  }

  // MARK: - Policy

  /// How long `toast` should stay up, or `nil` to stay until dismissed.
  nonisolated static func displayDuration(
    for toast: Toast,
    base: Duration,
    isVoiceOverRunning: Bool
  ) -> Duration? {
    // Sticky under VoiceOver: any timer short enough to feel transient races the announcement.
    guard !isVoiceOverRunning else { return nil }
    return toast.action == nil ? base : actionDisplayDuration
  }
}
