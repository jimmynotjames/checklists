//
//  RatingPromptCoordinatorTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing

/// Covers the automatic App Store review prompt's decision core: the persisted counters, the
/// balanced-profile thresholds, the once-per-version guard, the presenter gate, and the two
/// analytics events — including that the counters keep working when analytics are opted out.
///
/// The native `requestReview` call itself is not under test. StoreKit never shows the dialog in
/// TestFlight or on a simulator and reports nothing back, so the eligibility logic is the whole
/// testable surface; the same split `simple-recurring-budgets` makes.
@Suite("Rating prompt — eligibility and request")
struct RatingPromptCoordinatorTests {
  /// A fixed install date and a UTC calendar so the day arithmetic does not depend on the
  /// machine running the suite.
  private static let installDate = Date(timeIntervalSinceReferenceDate: 600_000_000)
  private static var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    return calendar
  }

  private struct Harness {
    let coordinator: RatingPromptCoordinator
    let state: RatingPromptState
    let spy: SpyAnalyticsClient
  }

  /// A coordinator over a fresh in-memory store pre-stamped with `installDate`, wired to a spy.
  /// `optedIn: false` puts the real consent gate between the coordinator and the spy.
  private func makeHarness(optedIn: Bool = true) -> Harness {
    let store = InMemoryKeyValueStore()
    store.set(Self.installDate.timeIntervalSinceReferenceDate.description, forKey: RatingPromptState.installedAtKey)
    let state = RatingPromptState(store: store)
    let spy = SpyAnalyticsClient()
    let coordinator = RatingPromptCoordinator(
      state: state,
      analytics: ConsentGatedAnalyticsClient(wrapping: spy, isOptedIn: { optedIn }),
      calendar: Self.utcCalendar
    )
    return Harness(coordinator: coordinator, state: state, spy: spy)
  }

  private func day(_ offset: Int) -> Date {
    Self.installDate.addingTimeInterval(Double(offset) * 86400)
  }

  /// Drives the coordinator to the threshold: ten check-offs across three distinct days, all
  /// past the seven-day install age. The final check-off is on day 12, which is returned.
  @discardableResult
  private func driveToEligible(_ coordinator: RatingPromptCoordinator, appVersion: String = "1.0") -> Date {
    for _ in 0 ..< 8 {
      coordinator.recordItemChecked(now: day(10), appVersion: appVersion)
    }
    coordinator.recordItemChecked(now: day(11), appVersion: appVersion)
    coordinator.recordItemChecked(now: day(12), appVersion: appVersion)
    return day(12)
  }

  // MARK: - State

  @Test("the install date is stamped once and survives a second init over the same store")
  func installDateIsStable() {
    let store = InMemoryKeyValueStore()
    let stamped = RatingPromptState(store: store).installedAt
    #expect(RatingPromptState(store: store).installedAt == stamped)
  }

  @Test("counters and dates round-trip through the store")
  func stateRoundTrips() {
    let store = InMemoryKeyValueStore()
    let state = RatingPromptState(store: store)
    state.checkedItemCount = 4
    state.distinctCheckDayCount = 2
    state.lastCheckDayStart = day(3)
    state.firstEligibleAt = day(9)
    state.lastRequestedVersion = "1.2"

    let reread = RatingPromptState(store: store)
    #expect(reread.checkedItemCount == 4)
    #expect(reread.distinctCheckDayCount == 2)
    #expect(reread.lastCheckDayStart == day(3))
    #expect(reread.firstEligibleAt == day(9))
    #expect(reread.lastRequestedVersion == "1.2")

    reread.lastRequestedVersion = nil
    reread.firstEligibleAt = nil
    #expect(RatingPromptState(store: store).lastRequestedVersion == nil)
    #expect(RatingPromptState(store: store).firstEligibleAt == nil)
  }

  // MARK: - Counters

  @Test("a check-off advances the lifetime and distinct-day counters")
  func countersAdvance() {
    let harness = makeHarness()
    harness.coordinator.recordItemChecked(now: day(1))
    #expect(harness.state.checkedItemCount == 1)
    #expect(harness.state.distinctCheckDayCount == 1)
  }

  @Test("the distinct-day counter moves only on a new calendar day")
  func distinctDayOnlyOnNewDay() {
    let harness = makeHarness()
    harness.coordinator.recordItemChecked(now: day(1))
    harness.coordinator.recordItemChecked(now: day(1).addingTimeInterval(3600))
    #expect(harness.state.distinctCheckDayCount == 1)
    #expect(harness.state.checkedItemCount == 2)
    harness.coordinator.recordItemChecked(now: day(2))
    #expect(harness.state.distinctCheckDayCount == 2)
  }

  // MARK: - Eligibility

  @Test("all thresholds met → pending, and the eligible event fires exactly once")
  func eligibleWhenAllThresholdsMet() {
    let harness = makeHarness()
    let eligibleAt = driveToEligible(harness.coordinator)
    #expect(harness.coordinator.isRequestPending)
    #expect(harness.state.firstEligibleAt == eligibleAt)
    #expect(harness.spy.count(of: AnalyticsEvent.ratingPromptEligible) == 1)
    #expect(harness.spy.calls.contains(.setRatingPromptFirstEligibleAt(eligibleAt)))

    harness.coordinator.recordItemChecked(now: day(13))
    #expect(harness.spy.count(of: AnalyticsEvent.ratingPromptEligible) == 1)
  }

  @Test("below the lifetime-count threshold is not eligible")
  func belowCountThresholdNotEligible() {
    let harness = makeHarness()
    // Three distinct days and a fine install age, but only three check-offs.
    harness.coordinator.recordItemChecked(now: day(10))
    harness.coordinator.recordItemChecked(now: day(11))
    harness.coordinator.recordItemChecked(now: day(12))
    #expect(!harness.coordinator.isRequestPending)
    #expect(harness.spy.calls.isEmpty)
  }

  @Test("below the distinct-day threshold is not eligible")
  func belowDistinctDaysNotEligible() {
    let harness = makeHarness()
    for _ in 0 ..< 10 {
      harness.coordinator.recordItemChecked(now: day(10))
    }
    #expect(!harness.coordinator.isRequestPending)
  }

  @Test("an install younger than seven days is not eligible")
  func belowInstallAgeNotEligible() {
    let harness = makeHarness()
    // Ten check-offs over days 0, 1 and 2 — monotonic, as a real clock is; the distinct-day
    // counter compares against the *last* check day only, so jumping back and forth would count
    // every check as a new day.
    for index in 0 ..< 10 {
      harness.coordinator.recordItemChecked(now: day(min(index / 4, 2)))
    }
    #expect(harness.state.checkedItemCount == 10)
    #expect(harness.state.distinctCheckDayCount == 3)
    #expect(!harness.coordinator.isRequestPending)
  }

  // MARK: - Request and the once-per-version guard

  @Test("consuming records the version, clears pending, and fires the requested event")
  func consumeRecordsVersion() {
    let harness = makeHarness()
    let eligibleAt = driveToEligible(harness.coordinator, appVersion: "1.0")
    let requestedAt = eligibleAt.addingTimeInterval(2 * 86400)
    harness.coordinator.consumePendingRequest(now: requestedAt, appVersion: "1.0")

    #expect(!harness.coordinator.isRequestPending)
    #expect(harness.state.lastRequestedVersion == "1.0")
    #expect(
      harness.spy.properties(forFirst: AnalyticsEvent.ratingPromptRequested)
        == [AnalyticsProperty.timeSinceFirstEligibleBucket: "<7d"]
    )
    #expect(harness.spy.calls.last == .setRatingPromptLastRequestedAt(requestedAt))
  }

  @Test("consuming with nothing pending is a no-op")
  func consumeWithoutPendingIsNoOp() {
    let harness = makeHarness()
    harness.coordinator.consumePendingRequest(now: day(1), appVersion: "1.0")
    #expect(harness.state.lastRequestedVersion == nil)
    #expect(harness.spy.calls.isEmpty)
  }

  @Test("already asked this version → no new request; a new version asks again")
  func oncePerVersionGuard() {
    let harness = makeHarness()
    driveToEligible(harness.coordinator, appVersion: "1.0")
    harness.coordinator.consumePendingRequest(now: day(12), appVersion: "1.0")

    harness.coordinator.recordItemChecked(now: day(13), appVersion: "1.0")
    #expect(!harness.coordinator.isRequestPending)

    harness.coordinator.recordItemChecked(now: day(14), appVersion: "1.1")
    #expect(harness.coordinator.isRequestPending)
  }

  @Test("no shown or resolved event is ever emitted")
  func noOutcomeEvents() {
    let harness = makeHarness()
    driveToEligible(harness.coordinator)
    harness.coordinator.consumePendingRequest(now: day(12))
    #expect(
      harness.spy.trackedEventNames == [AnalyticsEvent.ratingPromptEligible, AnalyticsEvent.ratingPromptRequested]
    )
  }

  // MARK: - Pure helpers

  @Test("the presenter requests only when pending, on the list, and active")
  func presenterGate() {
    #expect(RatingPromptCoordinator.shouldRequestReview(isRequestPending: true, isOnChecklistsList: true, sceneIsActive: true))
    // Still on the checklist screen (or a sheet, or the main menu) → wait.
    #expect(!RatingPromptCoordinator.shouldRequestReview(isRequestPending: true, isOnChecklistsList: false, sceneIsActive: true))
    // Backgrounded → wait.
    #expect(!RatingPromptCoordinator.shouldRequestReview(isRequestPending: true, isOnChecklistsList: true, sceneIsActive: false))
    // Nothing pending → inert.
    #expect(!RatingPromptCoordinator.shouldRequestReview(isRequestPending: false, isOnChecklistsList: true, sceneIsActive: true))
  }

  @Test("the time-since-eligible bucket boundaries")
  func timeSinceFirstEligibleBuckets() {
    let start = day(0)
    #expect(RatingPromptCoordinator.timeSinceFirstEligibleBucket(firstEligibleAt: nil, now: start) == "<1d")
    #expect(RatingPromptCoordinator.timeSinceFirstEligibleBucket(firstEligibleAt: start, now: start) == "<1d")
    #expect(RatingPromptCoordinator.timeSinceFirstEligibleBucket(firstEligibleAt: start, now: day(1)) == "<7d")
    #expect(RatingPromptCoordinator.timeSinceFirstEligibleBucket(firstEligibleAt: start, now: day(7)) == "<30d")
    #expect(RatingPromptCoordinator.timeSinceFirstEligibleBucket(firstEligibleAt: start, now: day(30)) == "30d+")
  }

  // MARK: - Consent independence

  @Test("counters and eligibility advance while analytics are opted out")
  func countersIndependentOfConsent() {
    let harness = makeHarness(optedIn: false)
    driveToEligible(harness.coordinator)
    #expect(harness.state.checkedItemCount == 10)
    #expect(harness.state.distinctCheckDayCount == 3)
    #expect(harness.state.firstEligibleAt != nil)
    #expect(harness.coordinator.isRequestPending)
  }

  @Test("nothing reaches the client while opted out, and the guard still records the version")
  func noEventsWhenOptedOut() {
    let harness = makeHarness(optedIn: false)
    driveToEligible(harness.coordinator)
    harness.coordinator.consumePendingRequest(now: day(12), appVersion: "1.0")
    #expect(harness.spy.calls.isEmpty)
    #expect(harness.state.lastRequestedVersion == "1.0")
  }
}
