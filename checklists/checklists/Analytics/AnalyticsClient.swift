//
//  AnalyticsClient.swift
//  checklists
//

import Foundation

/**
 The product-analytics sink.

 Everything the app measures goes through this one protocol. There are two conformers:
 `ConsoleAnalyticsClient`, which prints in DEBUG and does nothing in Release, and
 `MixpanelAnalyticsClient`. The app picks one at launch; see core-docs/analytics-spec.md §7.1.

 **The PII contract, restated here because this is where a new `track` call gets written.**
 The default is deny. This app transmits:

   - screen views, action events, and integer counts;
   - `notes_length`, a character count;
   - `error_domain`, `error_code` and `error_operation` — a framework-authored domain string, an
     integer, and a bounded operation name. Never an `NSError`'s `userInfo`;
   - `checklist_name` — **the only free-text property**, an accepted risk documented at
     analytics-spec.md §4.4.

 It never transmits item names, item notes, or checklist notes; any Apple identifier; any iCloud
 or CloudKit identifier; or any text that came from `OSLog`. Adding a user-content property is a
 spec change, not a code-review decision.

 **Call sites go through this protocol, never through a concrete client.** Downcasting to
 `MixpanelAnalyticsClient` would put behaviour behind a type the test spy cannot stand in for.

 Diagnostics are a **separate channel** — `AppLog` in `Logging/AppLoggers.swift`. The two never
 feed each other (§11). That is why they live in different directories.
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
}

extension AnalyticsClient {
  /// Convenience for the many events that carry no properties of their own — the super
  /// properties still ride along.
  func track(_ event: String) {
    track(event, properties: nil)
  }

  // Default no-ops, so `ConsoleAnalyticsClient` and test doubles implement only what they care
  // about. The Mixpanel client overrides all three.
  func refreshSuperProperties() {}
  func refreshCohortPeopleProperties(checklistsCount _: Int) {}
  func setAnalyticsOptInAt() {}
}
