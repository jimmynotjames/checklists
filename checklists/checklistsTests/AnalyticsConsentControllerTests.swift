//
//  AnalyticsConsentControllerTests.swift
//  checklistsTests
//

@testable import checklists
import Testing

/// Exercises `AnalyticsConsentController` against the **real** controller and a spy client, so
/// the ordering contract in core-docs/analytics-spec.md §6.3 is asserted against production
/// code rather than re-simulated inside the test body.
@Suite("Analytics consent controller")
struct AnalyticsConsentControllerTests {
  @Test("accepting tracks the consent change, stamps the opt-in timestamp, and sets the flag explicitly")
  func acceptTracksThenStampsTheOptInTimestampAndSetsTheFlagExplicitly() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = false
    let spy = SpyAnalyticsClient()
    let controller = AnalyticsConsentController(settings: settings, analytics: spy)

    controller.accept()

    #expect(
      spy.calls == [
        .track(AnalyticsEvent.analyticsConsentChanged, ["new_value": "true", "old_value": "false"]),
        .setAnalyticsOptInAt,
      ]
    )
    #expect(settings.analyticsOptIn)
    #expect(settings.analyticsOptInExplicitlySet)
  }

  /// The flag has to already be `true` at the moment `track` fires, not merely `true` by the
  /// time the method returns — a real Mixpanel client's lazy initializer reads it inline with
  /// this call. `SpyAnalyticsClient`'s ordered `calls` array proves event-to-event order but not
  /// order relative to a different object's mutation, so this uses a purpose-built snapshotting
  /// double instead.
  @Test("accepting sets the opt-in flag before tracking the consent event")
  func acceptSetsTheFlagBeforeTracking() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    let snapshotter = FlagSnapshottingAnalyticsClient(settings: settings)
    let controller = AnalyticsConsentController(settings: settings, analytics: snapshotter)

    controller.accept()

    #expect(snapshotter.optInStateWhenTracked == true)
  }

  @Test("declining sends no event but marks the choice explicit")
  func declineSendsNoEventButMarksTheChoiceExplicit() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    let spy = SpyAnalyticsClient()
    let controller = AnalyticsConsentController(settings: settings, analytics: spy)

    controller.decline()

    #expect(spy.calls.isEmpty)
    #expect(!settings.analyticsOptIn)
    #expect(
      settings.analyticsOptInExplicitlySet,
      """
      Without an explicit false, the sheet would re-present on every checklist open. A \
      swipe-to-dismiss routes to this same method, so it shares this coverage.
      """
    )
  }

  @Test("toggling off tracks the consent change, then resets, then clears the flag")
  func togglingOffTracksThenResetsThenClearsTheFlag() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = true
    let spy = SpyAnalyticsClient()
    let controller = AnalyticsConsentController(settings: settings, analytics: spy)

    controller.setOptIn(false)

    #expect(
      spy.calls == [
        .track(AnalyticsEvent.analyticsConsentChanged, ["new_value": "false", "old_value": "true"]),
        .reset,
      ]
    )
    #expect(!settings.analyticsOptIn)
  }

  /// The opt-out event is the only record the opt-out happened, so it must be sent *while still
  /// opted in* — before `reset()` and before the flag flips.
  @Test("toggling off tracks the consent change while still opted in")
  func togglingOffTracksWhileStillOptedIn() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = true
    let snapshotter = FlagSnapshottingAnalyticsClient(settings: settings)
    let controller = AnalyticsConsentController(settings: settings, analytics: snapshotter)

    controller.setOptIn(false)

    #expect(snapshotter.optInStateWhenTracked == true)
    #expect(!settings.analyticsOptIn)
  }

  @Test("toggling on tracks the consent change, then stamps the opt-in timestamp")
  func togglingOnTracksThenStampsTheOptInTimestamp() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    let spy = SpyAnalyticsClient()
    let controller = AnalyticsConsentController(settings: settings, analytics: spy)

    controller.setOptIn(true)

    #expect(
      spy.calls == [
        .track(AnalyticsEvent.analyticsConsentChanged, ["new_value": "true", "old_value": "false"]),
        .setAnalyticsOptInAt,
      ]
    )
    #expect(settings.analyticsOptIn)
  }

  /// The ordered `calls` array alone cannot catch a swap of the flag-write and the `track` call
  /// inside `setOptIn(true)`'s branch — both orders produce the same final calls and the same
  /// final flag value. This needs the same snapshotting technique `acceptSetsTheFlagBeforeTracking`
  /// uses.
  @Test("toggling on sets the opt-in flag before tracking the consent event")
  func togglingOnSetsTheFlagBeforeTracking() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = false
    let snapshotter = FlagSnapshottingAnalyticsClient(settings: settings)
    let controller = AnalyticsConsentController(settings: settings, analytics: snapshotter)

    controller.setOptIn(true)

    #expect(snapshotter.optInStateWhenTracked == true)
  }

  /// Likewise, the ordered `calls` array cannot catch a swap of `reset()` and the flag-write
  /// inside `setOptIn(false)`'s branch — `[track, reset]` and the final `false` flag look
  /// identical either way. `reset()` has to run *while the flag is still true*, or a real
  /// Mixpanel client's `reset()` would already be racing a flag that says "opted out."
  @Test("toggling off resets while the flag is still true")
  func togglingOffResetsWhileTheFlagIsStillTrue() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = true
    let snapshotter = FlagSnapshottingAnalyticsClient(settings: settings)
    let controller = AnalyticsConsentController(settings: settings, analytics: snapshotter)

    controller.setOptIn(false)

    #expect(snapshotter.optInStateWhenReset == true)
    #expect(!settings.analyticsOptIn)
  }
}

// MARK: - FlagSnapshottingAnalyticsClient

/// Records `settings.analyticsOptIn`'s value at the moment `track` and `reset` were each
/// called — the one thing `SpyAnalyticsClient`'s ordered `calls` array cannot prove, since the
/// flag write is a mutation on a different object, not a call the spy observes.
///
/// `@MainActor` is load-bearing here and not redundant with the target's default isolation, for the
/// same reason it is on `SpyAnalyticsClient`: `AnalyticsClient` requires `Sendable`, and a class
/// with mutable stored properties only satisfies that through actor isolation.
@MainActor
private final class FlagSnapshottingAnalyticsClient: AnalyticsClient {
  private let settings: AnalyticsSettings
  private(set) var optInStateWhenTracked: Bool?
  private(set) var optInStateWhenReset: Bool?

  init(settings: AnalyticsSettings) {
    self.settings = settings
  }

  func track(_: String, properties _: [String: any Sendable]?) {
    optInStateWhenTracked = settings.analyticsOptIn
  }

  func identify(_: String?) {}

  func reset() {
    optInStateWhenReset = settings.analyticsOptIn
  }
}
