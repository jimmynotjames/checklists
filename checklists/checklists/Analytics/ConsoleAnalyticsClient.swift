//
//  ConsoleAnalyticsClient.swift
//  checklists
//

/// Prints product events to the Xcode console in DEBUG; silent in Release.
///
/// This is the SwiftUI environment default and the client the app uses whenever Mixpanel should
/// not be talked to: during tests, and on a clone with no configured token
/// (core-docs/analytics-spec.md §Client selection).
///
/// Printing in DEBUG, rather than staying silent, is deliberate: it's the only way to confirm locally that an event fires as expected.
final class ConsoleAnalyticsClient: AnalyticsClient {
  func track(_ event: String, properties: [String: any Sendable]?) {
    #if DEBUG
      if let properties, !properties.isEmpty {
        print("[analytics] \(event) \(properties)") // check-strings:ignore
      } else {
        print("[analytics] \(event)") // check-strings:ignore
      }
    #endif
  }

  func identify(_ distinctId: String?) {
    #if DEBUG
      print("[analytics] identify \(distinctId ?? "nil")") // check-strings:ignore
    #endif
  }

  func reset() {
    #if DEBUG
      print("[analytics] reset") // check-strings:ignore
    #endif
  }
}
