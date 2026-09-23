//
//  ContainerBacking.swift
//  checklists
//

import Foundation

/// Which store the app actually ended up running on, decided once at launch and never mutated
/// afterwards. `ProductionContainerFactory` decides it on a real launch; a test or screenshot run
/// is handed `.localFallback` by `LaunchModeContainerFactory` without the factory being consulted.
///
/// This is deliberately *not* "is the user signed into iCloud" — that is a separate, live signal
/// (`SyncStatus.AccountStatus`). The two combine into a single user-facing status in `SyncStatus`;
/// keeping them apart is what lets the Settings row distinguish "you are signed in but this launch
/// is running on the local store" from "you are not signed in at all".
enum ContainerBacking {
  case cloudKit
  case localFallback
}
