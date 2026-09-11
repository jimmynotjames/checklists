//
//  ConsentGatedAnalyticsClient.swift
//  checklists
//

/// Wraps any `AnalyticsClient` and suppresses every method except `reset()` while the person is
/// opted out (core-docs/analytics-spec.md §2's canonical constraint #3: an opted-out install
/// never opens a connection).
///
/// A decorator rather than a guard inside each client, on purpose: it is testable today against
/// `SpyAnalyticsClient` with no SDK involved, there is exactly one gate rather than one per
/// client, and in a later PR wrapping `MixpanelAnalyticsClient` still preserves that client's
/// lazy-init guarantee — a `track` this gate suppresses never reaches its `ensureInitialized()`,
/// because it never reaches the wrapped client at all.
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

  /// **Always passes through, ungated.** The controller calls this *during* the opt-out
  /// transition, before the flag has flipped to `false` — gating on the current opt-in state
  /// would silently no-op the one reset that matters, leaving the wrapped client's identity and
  /// queued events in place on exactly the transition meant to clear them.
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
}
