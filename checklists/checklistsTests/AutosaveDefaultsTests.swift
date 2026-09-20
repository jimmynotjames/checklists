//
//  AutosaveDefaultsTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import Testing

/// Pins the autosave defaults, because nothing in the repo sets them and
/// `core-docs/persistence-design.md` §Autosave reasons about failed saves on the basis of them.
///
/// They are SwiftData's defaults rather than ours, so without this they would be an assumption
/// about a framework, asserted in prose and checked by nobody.
@Suite("Autosave defaults")
struct AutosaveDefaultsTests {
  /// What the app writes through: `PersistenceController.mainContext` and the `\.modelContext` that
  /// `.modelContainer(_:)` publishes are both this context.
  @Test("a container's main context autosaves")
  func mainContextAutosaves() throws {
    let container = try TestModelContainer.make()

    #expect(container.mainContext.autosaveEnabled)
  }

  /// What every unit test writes through, via `TestModelContainer.makeContext()`.
  ///
  /// It autosaves too, which is worth pinning precisely because it is easy to assume otherwise: a
  /// hand-built context looks like the manual-save option, and a test that means to prove nothing
  /// was persisted cannot rely on one holding its changes back.
  @Test("a hand-built context autosaves as well")
  func handBuiltContextAutosaves() throws {
    let container = try TestModelContainer.make()

    #expect(ModelContext(container).autosaveEnabled)
  }
}
