//
//  ContainerLaunchResult.swift
//  checklists
//

import Foundation
import SwiftData

/// What building this launch's `ModelContainer` decided: which store backs it, and — on a
/// CloudKit launch that fell back to the local store — the error that caused it. A named type
/// rather than a tuple: `ProductionContainerFactory.make`, `LaunchModeContainerFactory.make` and
/// `AppStartupCoordinator.MakeContainer` all return one, and a three-element tuple trips
/// `large_tuple` (`.swiftlint.yml`).
struct ContainerLaunchResult {
  let container: ModelContainer
  let backing: ContainerBacking
  let fallbackError: SyncErrorCode?
}
