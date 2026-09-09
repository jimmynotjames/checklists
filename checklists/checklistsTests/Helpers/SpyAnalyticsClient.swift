//
//  SpyAnalyticsClient.swift
//  checklistsTests
//

@testable import checklists
import Foundation

/// Records analytics calls so tests can assert on them.
///
/// Calls go into **one ordered array** rather than separate per-method collections. That matters
/// for the consent contract (analytics-spec.md §6.3), where the requirement is that the opt-out
/// event is sent *before* `reset()` — an ordering that parallel arrays cannot express, and which
/// would otherwise have to be re-simulated inside the test rather than observed on real code.
/// `@MainActor` so the recorded calls can be mutable state while still satisfying the protocol's
/// `Sendable` requirement — the isolation is what makes it safe. Every test method is `@MainActor`
/// already, so this costs call sites nothing.
@MainActor
final class SpyAnalyticsClient: AnalyticsClient {
  enum Call: Equatable {
    case track(String, [String: String]?)
    case identify(String?)
    case reset
    case refreshSuperProperties
    case refreshCohort(Int)
    case setAnalyticsOptInAt
  }

  private(set) var calls: [Call] = []

  // MARK: - Convenience accessors

  var trackedEventNames: [String] {
    calls.compactMap { if case let .track(name, _) = $0 { name } else { nil } }
  }

  /// The properties of the first `track` of `event`, stringified so assertions can compare them
  /// without caring whether a value arrived as an `Int` or a `String`.
  func properties(forFirst event: String) -> [String: String]? {
    for case let .track(name, properties) in calls where name == event {
      return properties
    }
    return nil
  }

  func count(of event: String) -> Int {
    trackedEventNames.count { $0 == event }
  }

  // MARK: - AnalyticsClient

  func track(_ event: String, properties: [String: any Sendable]?) {
    calls.append(.track(event, properties.map { $0.mapValues { value in String(describing: value) } }))
  }

  func identify(_ distinctId: String?) {
    calls.append(.identify(distinctId))
  }

  func reset() {
    calls.append(.reset)
  }

  func refreshSuperProperties() {
    calls.append(.refreshSuperProperties)
  }

  func refreshCohortPeopleProperties(checklistsCount: Int) {
    calls.append(.refreshCohort(checklistsCount))
  }

  func setAnalyticsOptInAt() {
    calls.append(.setAnalyticsOptInAt)
  }
}
