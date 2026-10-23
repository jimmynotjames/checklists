//
//  ContainerCreationFailureTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing

/// Covers the value the failure screen is built from: what it keeps out of a support email, and
/// which stage is allowed to offer the destructive reset.
@Suite("ContainerCreationFailure")
struct ContainerCreationFailureTests {
  @Test("a plain NSError keeps its domain and code")
  func plainErrorPassesThroughDomainAndCode() {
    let failure = ContainerCreationFailure(
      underlying: NSError(domain: "NSCocoaErrorDomain", code: 134_060),
      stage: .storeOpen,
    )

    #expect(failure.stage == .storeOpen)
    #expect(failure.errorDomain == "NSCocoaErrorDomain")
    #expect(failure.errorCode == 134_060)
  }

  /// `PersistenceError` is a Swift struct, so bridging it would report
  /// `checklists.PersistenceError 1` and collapse every import and seed save failure into one
  /// bucket while the real domain and code sat unread in its own fields.
  @Test("a PersistenceError is unwrapped rather than bridged")
  func persistenceErrorIsUnwrapped() {
    let failure = ContainerCreationFailure(
      underlying: PersistenceError(operation: .legacyImport, errorDomain: "NSCocoaErrorDomain", errorCode: 134_030),
      stage: .legacyImport,
    )

    #expect(failure.errorDomain == "NSCocoaErrorDomain")
    #expect(failure.errorCode == 134_030)
  }

  /// The case that makes explicit tagging necessary rather than merely tidy: the legacy import
  /// throws a Swift enum carrying no domain, no code and no operation, so there is nothing in the
  /// error to infer a stage from. The stage still has to be right.
  @Test("an error carrying no stage information is still tagged")
  func opaqueErrorIsStillTagged() {
    let failure = ContainerCreationFailure(
      underlying: LegacyRealmImporter.ImportError.verificationFailed(
        expectedChecklists: 3,
        foundChecklists: 2,
        expectedItems: 9,
        foundItems: 9,
      ),
      stage: .legacyImport,
    )

    #expect(failure.stage == .legacyImport)
    #expect(!failure.allowsStoreReset)
  }

  /// Pinned as an exact string: a regression that appended `localizedDescription` would put the
  /// user's own content into a support email body and a public log line.
  @Test("the diagnostic description is the stage, domain and code only")
  func diagnosticDescriptionIsTerse() {
    let failure = ContainerCreationFailure(
      stage: .legacyImport,
      errorDomain: "NSCocoaErrorDomain",
      errorCode: 134_060,
    )

    #expect(failure.diagnosticDescription == "legacy_import NSCocoaErrorDomain 134060")
  }

  /// Written over `allCases` so a stage added later fails here until someone decides, deliberately,
  /// whether it may delete the user's checklists and their Realm file.
  @Test("only a store that would not open offers the destructive reset")
  func onlyStoreOpenAllowsReset() {
    for stage in ContainerCreationFailure.Stage.allCases {
      let failure = ContainerCreationFailure(stage: stage, errorDomain: "NSCocoaErrorDomain", errorCode: 134_060)
      #expect(failure.allowsStoreReset == (stage == .storeOpen), "Unreviewed reset policy for \(stage.rawValue).")
    }
  }

  @Test("two failures differing only in stage are not equal")
  func stageParticipatesInEquality() {
    let openFailure = ContainerCreationFailure(stage: .storeOpen, errorDomain: "D", errorCode: 1)
    let seedFailure = ContainerCreationFailure(stage: .firstLaunchSeed, errorDomain: "D", errorCode: 1)

    #expect(openFailure != seedFailure)
  }
}
