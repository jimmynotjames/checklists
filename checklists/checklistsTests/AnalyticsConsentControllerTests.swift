//
//  AnalyticsConsentControllerTests.swift
//  checklistsTests
//

@testable import checklists
import XCTest

/// Exercises `AnalyticsConsentController` against the **real** controller and a spy client, so
/// the ordering contract in core-docs/analytics-spec.md §6.3 is asserted against production
/// code rather than re-simulated inside the test body.
///
/// See the note on `AnalyticsTextTests` for the `nonisolated` class / `@MainActor` method
/// pattern.
nonisolated final class AnalyticsConsentControllerTests: XCTestCase {
  @MainActor func testAcceptTracksThenStampsTheOptInTimestampAndSetsTheFlagExplicitly() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = false
    let spy = SpyAnalyticsClient()
    let controller = AnalyticsConsentController(settings: settings, analytics: spy)

    controller.accept()

    XCTAssertEqual(
      spy.calls,
      [
        .track(AnalyticsEvent.analyticsConsentChanged, ["new_value": "true", "old_value": "false"]),
        .setAnalyticsOptInAt,
      ]
    )
    XCTAssertTrue(settings.analyticsOptIn)
    XCTAssertTrue(settings.analyticsOptInExplicitlySet)
  }

  /// The flag has to already be `true` at the moment `track` fires, not merely `true` by the
  /// time the method returns — a real Mixpanel client's lazy initializer reads it inline with
  /// this call. `SpyAnalyticsClient`'s ordered `calls` array proves event-to-event order but not
  /// order relative to a different object's mutation, so this uses a purpose-built snapshotting
  /// double instead.
  @MainActor func testAcceptSetsTheFlagBeforeTracking() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    let snapshotter = FlagSnapshottingAnalyticsClient(settings: settings)
    let controller = AnalyticsConsentController(settings: settings, analytics: snapshotter)

    controller.accept()

    XCTAssertEqual(snapshotter.optInStateWhenTracked, true)
  }

  @MainActor func testDeclineSendsNoEventButMarksTheChoiceExplicit() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    let spy = SpyAnalyticsClient()
    let controller = AnalyticsConsentController(settings: settings, analytics: spy)

    controller.decline()

    XCTAssertTrue(spy.calls.isEmpty)
    XCTAssertFalse(settings.analyticsOptIn)
    XCTAssertTrue(
      settings.analyticsOptInExplicitlySet,
      "Without an explicit false, the sheet would re-present on every checklist open. A "
        + "swipe-to-dismiss routes to this same method, so it shares this coverage."
    )
  }

  @MainActor func testTogglingOffTracksThenResetsThenClearsTheFlag() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = true
    let spy = SpyAnalyticsClient()
    let controller = AnalyticsConsentController(settings: settings, analytics: spy)

    controller.setOptIn(false)

    XCTAssertEqual(
      spy.calls,
      [
        .track(AnalyticsEvent.analyticsConsentChanged, ["new_value": "false", "old_value": "true"]),
        .reset,
      ]
    )
    XCTAssertFalse(settings.analyticsOptIn)
  }

  /// The opt-out event is the only record the opt-out happened, so it must be sent *while still
  /// opted in* — before `reset()` and before the flag flips.
  @MainActor func testTogglingOffTracksWhileStillOptedIn() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = true
    let snapshotter = FlagSnapshottingAnalyticsClient(settings: settings)
    let controller = AnalyticsConsentController(settings: settings, analytics: snapshotter)

    controller.setOptIn(false)

    XCTAssertEqual(snapshotter.optInStateWhenTracked, true)
    XCTAssertFalse(settings.analyticsOptIn)
  }

  @MainActor func testTogglingOnTracksThenStampsTheOptInTimestamp() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    let spy = SpyAnalyticsClient()
    let controller = AnalyticsConsentController(settings: settings, analytics: spy)

    controller.setOptIn(true)

    XCTAssertEqual(
      spy.calls,
      [
        .track(AnalyticsEvent.analyticsConsentChanged, ["new_value": "true", "old_value": "false"]),
        .setAnalyticsOptInAt,
      ]
    )
    XCTAssertTrue(settings.analyticsOptIn)
  }

  /// The ordered `calls` array alone cannot catch a swap of the flag-write and the `track` call
  /// inside `setOptIn(true)`'s branch — both orders produce the same final calls and the same
  /// final flag value. This needs the same snapshotting technique `testAcceptSetsTheFlagBeforeTracking`
  /// uses.
  @MainActor func testTogglingOnSetsTheFlagBeforeTracking() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = false
    let snapshotter = FlagSnapshottingAnalyticsClient(settings: settings)
    let controller = AnalyticsConsentController(settings: settings, analytics: snapshotter)

    controller.setOptIn(true)

    XCTAssertEqual(snapshotter.optInStateWhenTracked, true)
  }

  /// Likewise, the ordered `calls` array cannot catch a swap of `reset()` and the flag-write
  /// inside `setOptIn(false)`'s branch — `[track, reset]` and the final `false` flag look
  /// identical either way. `reset()` has to run *while the flag is still true*, or a real
  /// Mixpanel client's `reset()` would already be racing a flag that says "opted out."
  @MainActor func testTogglingOffResetsWhileTheFlagIsStillTrue() {
    let settings = AnalyticsSettings(store: InMemoryKeyValueStore())
    settings.analyticsOptIn = true
    let snapshotter = FlagSnapshottingAnalyticsClient(settings: settings)
    let controller = AnalyticsConsentController(settings: settings, analytics: snapshotter)

    controller.setOptIn(false)

    XCTAssertEqual(snapshotter.optInStateWhenReset, true)
    XCTAssertFalse(settings.analyticsOptIn)
  }
}

// MARK: - FlagSnapshottingAnalyticsClient

/// Records `settings.analyticsOptIn`'s value at the moment `track` and `reset` were each
/// called — the one thing `SpyAnalyticsClient`'s ordered `calls` array cannot prove, since the
/// flag write is a mutation on a different object, not a call the spy observes.
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
