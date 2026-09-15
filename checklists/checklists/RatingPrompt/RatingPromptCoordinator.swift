//
//  RatingPromptCoordinator.swift
//  checklists
//

import Foundation
import Observation

/// Decision core for the automatic App Store review prompt.
///
/// Ported from `simple-recurring-budgets`'s `RatingPromptCoordinator`, whose thresholds are the
/// calibration this app wants. There, the qualifying action is logging an expense; here it is
/// **checking off an item** — the one thing people open this app to do. Each check-off advances
/// the persisted counters in `RatingPromptState`, and once every threshold below holds — and no
/// review has been requested for the running app version — `isRequestPending` flips. The root
/// presenter (`ratingPromptPresenter()`) watches that flag and calls Apple's native
/// `requestReview` once the person is back on the checklists list with the scene active, then
/// calls `consumePendingRequest()`.
///
/// **The prompt is never shown mid-task.** Checking an item happens on the checklist screen; the
/// request waits until that screen has been left, so it lands on the list between tasks rather
/// than over a half-finished checklist. Unchecking is not a qualifying action: it reads as a reset,
/// not as progress.
///
/// No custom rating dialog and no "enjoying the app?" pre-prompt — review-gating hurts ratings and
/// the app does not pressure anyone. Re-prompt prevention is the once-per-version guard here plus
/// Apple's own throttle (at most three prompts per 365 days, and none for a version already rated).
/// The native API reports neither whether StoreKit showed the dialog nor what the person chose, so
/// nothing here depends on an outcome, and analytics stop at `rating_prompt_requested`.
@Observable
@MainActor
final class RatingPromptCoordinator {
  /// Balanced-profile thresholds, unchanged from `simple-recurring-budgets`.
  static let minInstallAgeDays = 7
  static let minDistinctCheckDays = 3
  static let minCheckedItems = 10

  /// Transient and **not** persisted: set when a qualifying check-off makes the install eligible,
  /// cleared after the presenter has requested a review. If the process dies in between, the next
  /// qualifying check-off sets it again — nothing is lost but a little time.
  var isRequestPending = false

  private let state: RatingPromptState
  private let analytics: any AnalyticsClient
  private let calendar: Calendar

  init(
    state: RatingPromptState,
    analytics: any AnalyticsClient,
    calendar: Calendar = .autoupdatingCurrent
  ) {
    self.state = state
    self.analytics = analytics
    self.calendar = calendar
  }

  /// Records one item being checked off and advances eligibility.
  ///
  /// `now` and `appVersion` are parameters so the tests can drive the calendar and the
  /// once-per-version guard without a clock or a bundle.
  func recordItemChecked(
    now: Date = Date(),
    appVersion: String = RatingPromptCoordinator.currentAppVersion
  ) {
    advanceCounters(now: now)

    let eligible =
      installAgeDays(now: now) >= Self.minInstallAgeDays
        && state.distinctCheckDayCount >= Self.minDistinctCheckDays
        && state.checkedItemCount >= Self.minCheckedItems

    if eligible, state.firstEligibleAt == nil {
      state.firstEligibleAt = now
      analytics.track(AnalyticsEvent.ratingPromptEligible)
      analytics.setRatingPromptFirstEligibleAt(now)
    }

    if eligible, state.lastRequestedVersion != appVersion {
      isRequestPending = true
    }
  }

  /// Called by the presenter immediately after it invokes `requestReview`. Records the version
  /// (the once-per-version guard), clears the pending flag, and fires `rating_prompt_requested`.
  func consumePendingRequest(
    now: Date = Date(),
    appVersion: String = RatingPromptCoordinator.currentAppVersion
  ) {
    guard isRequestPending else { return }
    isRequestPending = false
    state.lastRequestedVersion = appVersion
    analytics.track(
      AnalyticsEvent.ratingPromptRequested,
      properties: [
        AnalyticsProperty.timeSinceFirstEligibleBucket:
          Self.timeSinceFirstEligibleBucket(firstEligibleAt: state.firstEligibleAt, now: now),
      ]
    )
    analytics.setRatingPromptLastRequestedAt(now)
  }

  // MARK: - Pure decision helpers

  // `nonisolated`: these are pure functions of their arguments (AGENTS.md §Concurrency), and
  // `currentAppVersion` is also read as a default argument, which is evaluated outside the
  // actor — the isolation the class default would give them is a compile error there.

  /// Whether the presenter should request a review right now. Pure so the gate is unit-testable;
  /// the `requestReview()` call itself stays in `RatingPromptPresenter`.
  ///
  /// `isOnChecklistsList` is the "not mid-task" gate: no route pushed, no sheet up, main menu
  /// closed. It is what defers the request until the checklist screen has been left.
  nonisolated static func shouldRequestReview(
    isRequestPending: Bool,
    isOnChecklistsList: Bool,
    sceneIsActive: Bool
  ) -> Bool {
    isRequestPending && isOnChecklistsList && sceneIsActive
  }

  /// Buckets the gap between first eligibility and the request. Coarse on purpose: no raw
  /// timestamp reaches an event (the people property carries the exact moment, per §9.3).
  nonisolated static func timeSinceFirstEligibleBucket(firstEligibleAt: Date?, now: Date) -> String {
    guard let firstEligibleAt else { return "<1d" }
    let days = now.timeIntervalSince(firstEligibleAt) / 86400
    return switch days {
    case ..<1: "<1d"
    case ..<7: "<7d"
    case ..<30: "<30d"
    default: "30d+"
    }
  }

  /// `CFBundleShortVersionString`, the same value `app_version` carries (§9.2).
  nonisolated static var currentAppVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
  }

  // MARK: - Private

  private func advanceCounters(now: Date) {
    state.checkedItemCount += 1
    let dayStart = calendar.startOfDay(for: now)
    if let last = state.lastCheckDayStart, calendar.isDate(last, inSameDayAs: dayStart) {
      return
    }
    state.distinctCheckDayCount += 1
    state.lastCheckDayStart = dayStart
  }

  private func installAgeDays(now: Date) -> Int {
    calendar.dateComponents([.day], from: state.installedAt, to: now).day ?? 0
  }
}
