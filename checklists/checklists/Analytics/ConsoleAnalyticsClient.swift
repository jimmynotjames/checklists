//
//  ConsoleAnalyticsClient.swift
//  checklists
//

/// Prints product events to the Xcode console in DEBUG; silent in Release.
///
/// This is the SwiftUI environment default and the client the app uses whenever Mixpanel should
/// not be talked to: during tests, and on a clone with no configured token (§7.1).
///
/// Printing rather than staying silent is deliberate. The Flurry integration compiled analytics
/// out of debug builds entirely, which made it impossible to check locally whether an event fired
/// with the right properties — the reason instrumentation drifted.
final class ConsoleAnalyticsClient: AnalyticsClient {
  func track(_ event: String, properties: [String: any Sendable]?) {
    #if DEBUG
      if let properties, !properties.isEmpty {
        print("[analytics] \(event) \(properties)")
      } else {
        print("[analytics] \(event)")
      }
    #endif
  }

  func identify(_ distinctId: String?) {
    #if DEBUG
      print("[analytics] identify \(distinctId ?? "nil")")
    #endif
  }

  func reset() {
    #if DEBUG
      print("[analytics] reset")
    #endif
  }
}
