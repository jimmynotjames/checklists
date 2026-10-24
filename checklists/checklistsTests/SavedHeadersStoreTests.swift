//
//  SavedHeadersStoreTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import Testing

/// Covers the export sheet's Saved Headers: what counts as new, the order the menu shows, and that
/// they persist.
@Suite("Saved Headers store")
struct SavedHeadersStoreTests {
  @Test("saving trims the text and puts the newest first")
  func savingTrimsAndPutsNewestFirst() {
    let store = SavedHeadersStore(store: InMemoryKeyValueStore())

    store.save("  Acme Plumbing\n")
    store.save("Licence 12345")

    #expect(store.headers == ["Licence 12345", "Acme Plumbing"])
  }

  /// "Acme" and "Acme⏎" must not become two menu entries that look identical.
  @Test("text differing only in surrounding whitespace is the same Saved Header")
  func surroundingWhitespaceDoesNotMakeANewEntry() {
    let store = SavedHeadersStore(store: InMemoryKeyValueStore())
    store.save("Acme")

    #expect(!store.canSave("Acme\n"))
    store.save("  Acme ")
    #expect(store.headers == ["Acme"])
  }

  @Test("Save for Reuse does not apply to an empty or whitespace-only field")
  func emptyTextCannotBeSaved() {
    let store = SavedHeadersStore(store: InMemoryKeyValueStore())

    #expect(!store.canSave(""))
    #expect(!store.canSave(" \n\t"))
  }

  /// Trusted to the person: a Saved Header with job details under it is new text.
  @Test("a Saved Header with more typed under it can be saved again")
  func savedHeaderPlusMoreIsNew() {
    let store = SavedHeadersStore(store: InMemoryKeyValueStore())
    store.save("Acme Plumbing")

    #expect(store.canSave("Acme Plumbing\n42 Example Street"))
  }

  @Test("deleting removes only that Saved Header")
  func deletingRemovesOnlyThatEntry() {
    let store = SavedHeadersStore(store: InMemoryKeyValueStore())
    store.save("Acme Plumbing")
    store.save("Licence 12345")

    store.delete("Acme Plumbing")

    #expect(store.headers == ["Licence 12345"])
  }

  @Test("Saved Headers persist to a new instance over the same store")
  func savedHeadersPersist() {
    let backing = InMemoryKeyValueStore()
    let store = SavedHeadersStore(store: backing)
    store.save("Acme Plumbing")
    store.save("Licence 12345")
    store.delete("Acme Plumbing")

    #expect(SavedHeadersStore(store: backing).headers == ["Licence 12345"])
  }

  @Test("unreadable stored data reads as nothing saved")
  func unreadableDataReadsAsEmpty() {
    let backing = InMemoryKeyValueStore()
    backing.set("not json", forKey: SavedHeadersStore.savedHeadersKey)

    #expect(SavedHeadersStore(store: backing).headers.isEmpty)
  }
}
