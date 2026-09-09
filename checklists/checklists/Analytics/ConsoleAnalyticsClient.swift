//
//  ConsoleAnalyticsClient.swift
//  checklists
//

/// Prints product events to the Xcode console in DEBUG; silent in Release.
///
/// This is the SwiftUI environment default and the client the app uses whenever Mixpanel should
/// not be talked to: during tests, and on a clone with no configured token (§7.1).
///
/// Printing rather than staying silent in DEBUG is deliberate: it is the only way to confirm
/// locally that an event fires, once, with the properties it should. Analytics that are compiled
/// out of debug builds cannot be checked before they ship.
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
