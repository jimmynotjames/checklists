//
//  AnalyticsEnvironment.swift
//  checklists
//

import SwiftUI

extension EnvironmentValues {
  /// The active analytics client.
  ///
  /// Defaults to `ConsoleAnalyticsClient` so a SwiftUI preview, or a view constructed in a test
  /// without the app around it, needs no setup and sends nothing. `ChecklistsApp` injects the
  /// real client for every startup phase.
  @Entry var analytics: any AnalyticsClient = ConsoleAnalyticsClient()
}
