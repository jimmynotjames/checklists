//
//  AnalyticsClient.swift
//  checklists
//

import Foundation

/**
 The product-analytics sink. Everything the app measures goes through this one protocol. The app
 has three conformers: `MixpanelAnalyticsClient`, `ConsoleAnalyticsClient`, and the
 `ConsentGatedAnalyticsClient` that wraps one of them. Selection:
 core-docs/analytics-spec.md §Client selection.

 **Before adding a property, read analytics-spec.md §Privacy.** The default is deny: a field not on
 its allow-list is a spec change, not a code-review decision.
 */
protocol AnalyticsClient: AnyObject, Sendable {
  /// Records one event. `properties` values must be property-list-ish scalars; anything the
  /// backend cannot represent is dropped rather than failing the build, so prefer the typed
  /// helpers in `Analytics+DomainExtensions.swift` over assembling dictionaries by hand.
  func track(_ event: String, properties: [String: any Sendable]?)

  /// Associates subsequent events with a person. See analytics-spec.md §Identity.
  func identify(_ distinctId: String?)

  /// Drops the current identity and any queued events. Called when someone opts out
  /// (analytics-spec.md §Toggle-off behaviour).
  func reset()

  /// Re-registers the super properties. **No production caller**: lazy SDK init registers them,
  /// including after reset → re-opt-in. It stays so a spy can observe that nothing calls it.
  func refreshSuperProperties()

  /// Updates `checklists_count_bucket`, the one profile-level cohort signal.
  func refreshCohortPeopleProperties(checklistsCount: Int)

  /// Stamps `analytics_opt_in_at`.
  func setAnalyticsOptInAt()

  /// Stamps `rating_prompt_first_eligible_at`. Called once per install, right after
  /// `rating_prompt_eligible`.
  func setRatingPromptFirstEligibleAt(_ date: Date)

  /// Stamps `rating_prompt_last_requested_at`, on every `rating_prompt_requested`.
  func setRatingPromptLastRequestedAt(_ date: Date)
}

extension AnalyticsClient {
  /// Convenience for the many events that carry no properties of their own — the super
  /// properties still ride along.
  func track(_ event: String) {
    track(event, properties: nil)
  }

  // Default no-ops, so `ConsoleAnalyticsClient` and test doubles implement only what they care
  // about. The Mixpanel client overrides all five.
  func refreshSuperProperties() {}
  func refreshCohortPeopleProperties(checklistsCount _: Int) {}
  func setAnalyticsOptInAt() {}
  func setRatingPromptFirstEligibleAt(_: Date) {}
  func setRatingPromptLastRequestedAt(_: Date) {}
}
