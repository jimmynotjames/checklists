//
//  ConsentGatedAnalyticsClient.swift
//  checklists
//

import Foundation

/// Wraps any `AnalyticsClient` and suppresses every method except `reset()` while the person is
/// opted out, so an opted-out install never opens a connection (core-docs/analytics-spec.md
/// §Launch and consent ordering).
///
/// A decorator rather than a guard inside each client: it is testable against
/// `SpyAnalyticsClient` with no SDK involved, there is one gate rather than one per client, and it
/// is what keeps `MixpanelAnalyticsClient`'s init lazy — a suppressed `track` never reaches the
/// wrapped client's `ensureInitialized()`.
final class ConsentGatedAnalyticsClient: AnalyticsClient, @unchecked Sendable {
  private let wrapped: any AnalyticsClient
  private let isOptedIn: () -> Bool

  init(wrapping wrapped: any AnalyticsClient, isOptedIn: @escaping () -> Bool) {
    self.wrapped = wrapped
    self.isOptedIn = isOptedIn
  }

  func track(_ event: String, properties: [String: any Sendable]?) {
    guard isOptedIn() else { return }
    wrapped.track(event, properties: properties)
  }

  func identify(_ distinctId: String?) {
    guard isOptedIn() else { return }
    wrapped.identify(distinctId)
  }

  /// **Always passes through, ungated**, so a reset opts the wrapped client out whatever the flag
  /// says — including one issued after it has flipped to `false`.
  func reset() {
    wrapped.reset()
  }

  func refreshSuperProperties() {
    guard isOptedIn() else { return }
    wrapped.refreshSuperProperties()
  }

  func refreshCohortPeopleProperties(checklistsCount: Int) {
    guard isOptedIn() else { return }
    wrapped.refreshCohortPeopleProperties(checklistsCount: checklistsCount)
  }

  func setAnalyticsOptInAt() {
    guard isOptedIn() else { return }
    wrapped.setAnalyticsOptInAt()
  }

  func setRatingPromptFirstEligibleAt(_ date: Date) {
    guard isOptedIn() else { return }
    wrapped.setRatingPromptFirstEligibleAt(date)
  }

  func setRatingPromptLastRequestedAt(_ date: Date) {
    guard isOptedIn() else { return }
    wrapped.setRatingPromptLastRequestedAt(date)
  }
}
