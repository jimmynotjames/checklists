//
//  ToastPresenter.swift
//  checklists
//

import SwiftUI
import UIKit

/**
 Holds the toast currently on screen and retires it on time.

 Newest wins: an arriving toast replaces whatever is up, immediately and unconditionally. Nothing
 is queued and nothing is merged, so no arriving toast's contents can be quietly discarded in
 favour of the one already showing. The cost is that two confirmations raised within a few hundred
 milliseconds of each other leave the first one unreadable, which no caller can currently do: a
 toast follows a deliberate action.

 Replacing does not remount the card — the overlay's structural identity is stable while a toast
 is up — so a repeated message updates in place rather than sliding out and back in. The VoiceOver
 announcement is keyed on the message for the same reason.

 The dismissal timer lives here rather than in `ToastLayer`'s `@State`, unlike
 `RatingPromptPresenter`'s: that one is driven only by `onChange` inside its own modifier, while a
 toast is raised from arbitrary call sites — including, once #218 lands, the UIKit screen. A timer
 in view state would be unreachable from those callers and orphaned whenever the modifier is
 re-instantiated.

 The display-duration decision is a `nonisolated static` function so it tests without a presenter,
 and the two sources of time — sleeping and the VoiceOver check — are injectable so the lifecycle
 tests need no clock.
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

  /// The one scheduled dismissal, and the only thing this slot ever holds — giving it a second
  /// job is what previously let one arriving toast cancel another on its way to the screen.
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
      // The id check keeps the invariant local. `Task.isCancelled` covers every path there is
      // today, because `current` only ever changes just after this slot is cancelled — but that
      // is a property of the two call sites, not of this task, and this way a third one cannot
      // quietly break it.
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
