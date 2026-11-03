//
//  AnalyticsConsentController.swift
//  checklists
//

import Foundation

/// Owns every transition of the analytics consent decision — the first-run sheet's accept and
/// decline, and the always-on Settings toggle — so the ordering in core-docs/analytics-spec.md
/// §Toggle-off behaviour is testable against production code rather than a SwiftUI binding.
///
/// **The order inside each method is the contract.** Get it wrong and the consent event is
/// either unsendable (the opt-in flag flips before the track that needs to see it) or lost (an
/// opt-out is tracked after the client has already been reset, or after the flag has already
/// gated it out).
@MainActor
final class AnalyticsConsentController {
  private let settings: AnalyticsSettings
  private let analytics: any AnalyticsClient

  init(settings: AnalyticsSettings, analytics: any AnalyticsClient) {
    self.settings = settings
    self.analytics = analytics
  }

  /// The first-run sheet's affirmative path. Reads the prior value for `old_value`, sets the flag
  /// first, so a lazy SDK initializer triggered by this `track` observes an opted-in state, then
  /// tracks the change, then stamps the opt-in timestamp people property.
  func accept() {
    let oldValue = settings.analyticsOptIn
    settings.analyticsOptIn = true
    analytics.track(
      AnalyticsEvent.analyticsConsentChanged,
      properties: [AnalyticsProperty.newValue: true, AnalyticsProperty.oldValue: oldValue],
    )
    analytics.setAnalyticsOptInAt()
  }

  /// The first-run sheet's negative path — reached from "Not now" or a swipe-to-dismiss alike.
  /// Writes an **explicit** `false` so the sheet's trigger guard never fires again, and sends no
  /// event: there is no live opted-in session to record a decline on.
  func decline() {
    settings.analyticsOptIn = false
  }

  /// The always-on Settings toggle. Opting in mirrors `accept()`, with `old_value` always `false`:
  /// the toggle can only be turned on from off. Opting out tracks the change *while still opted
  /// in*, then resets the client, then clears the flag.
  func setOptIn(_ newValue: Bool) {
    if newValue {
      settings.analyticsOptIn = true
      analytics.track(
        AnalyticsEvent.analyticsConsentChanged,
        properties: [AnalyticsProperty.newValue: true, AnalyticsProperty.oldValue: false],
      )
      analytics.setAnalyticsOptInAt()
    } else {
      analytics.track(
        AnalyticsEvent.analyticsConsentChanged,
        properties: [AnalyticsProperty.newValue: false, AnalyticsProperty.oldValue: true],
      )
      analytics.reset()
      settings.analyticsOptIn = false
    }
  }
}
