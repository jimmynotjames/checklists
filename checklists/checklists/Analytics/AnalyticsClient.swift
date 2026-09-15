//
//  AnalyticsClient.swift
//  checklists
//

import Foundation

/**
 The product-analytics sink. Everything the app measures goes through this one protocol — see
 core-docs/analytics-spec.md §7.1 for the two conformers and how the app picks one at launch.

 **The PII contract, restated here because this is where a new `track` call gets written.**
 The default is deny. This app transmits:
   - screen views, action events, and integer counts;
   - `notes_length`, a character count;
   - `error_domain`, `error_code` and `error_operation` — never an `NSError`'s `userInfo`;
   - `checklist_name` — **the only free-text property**, an accepted risk (analytics-spec §4.4).
 It never transmits item names, item notes, checklist notes, Apple/iCloud/CloudKit identifiers, or
 `OSLog` text. Adding a user-content property is a spec change, not a code-review decision.
 */
protocol AnalyticsClient: AnyObject, Sendable {
  /// Records one event. `properties` values must be property-list-ish scalars; anything the
  /// backend cannot represent is dropped rather than failing the build, so prefer the typed
  /// helpers in `Analytics+DomainExtensions.swift` over assembling dictionaries by hand.
  func track(_ event: String, properties: [String: any Sendable]?)

  /// Associates subsequent events with a person. See §5 for what the id is and is not.
  func identify(_ distinctId: String?)

  /// Drops the current identity and any queued events. Called when someone opts out (§6.3).
  func reset()

  /// Re-registers the properties attached to every event (§9.2).
  ///
  /// Deliberately has **no production caller**. Registration happens inside lazy SDK
  /// initialization (§7.2), which also covers the reset → re-opt-in path, so there is nothing for
  /// the app to call at launch. It stays on the protocol for a client that needs to refresh a
  /// super property mid-session — and so a spy can observe that nothing calls it.
  func refreshSuperProperties()

  /// Updates the one profile-level cohort signal this app has (§9.3).
  func refreshCohortPeopleProperties(checklistsCount: Int)

  /// Stamps the moment consent was granted (§9.3).
  func setAnalyticsOptInAt()

  /// Stamps the moment the rating-prompt thresholds were first met (§9.3). Called once per
  /// install, right after `rating_prompt_eligible`.
  func setRatingPromptFirstEligibleAt(_ date: Date)

  /// Stamps the moment `requestReview` was last called (§9.3). Refreshed on every
  /// `rating_prompt_requested`.
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
