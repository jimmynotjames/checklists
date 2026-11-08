//
//  RouterTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftUI
import Testing

@Suite("Router — which screen is in front")
struct RouterTests {
  @Test("ChecklistsView is frontmost only with no checklist open and no sheet")
  func checklistsViewFrontmost() {
    let router = Router()
    #expect(router.isChecklistsViewFrontmost)

    router.sheet = .settings
    #expect(!router.isChecklistsViewFrontmost)

    router.sheet = nil
    router.open(checklistID: "a")
    #expect(!router.isChecklistsViewFrontmost)

    router.closeChecklist(id: "a")
    #expect(router.isChecklistsViewFrontmost)
  }

  @Test("closing a checklist that is no longer the open one leaves the open one alone")
  func lateCloseKeepsSuccessor() {
    let router = Router()
    router.open(checklistID: "a")
    router.open(checklistID: "b")

    router.closeChecklist(id: "a")
    #expect(router.selectedChecklistID == "b")

    router.closeChecklist(id: "b")
    #expect(router.selectedChecklistID == nil)
  }

  @Test("an open checklist is frontmost until a sheet covers it, and only that checklist")
  func checklistFrontmost() {
    let router = Router()
    #expect(!router.isFrontmost(checklistID: "a"))

    router.open(checklistID: "a")
    #expect(router.isFrontmost(checklistID: "a"))
    #expect(!router.isFrontmost(checklistID: "b"))

    router.sheet = .settings
    #expect(!router.isFrontmost(checklistID: "a"))
  }

  @Test("the compact column shows the open checklist, or ChecklistsView with none")
  func compactColumnReadsSelection() {
    let router = Router()
    #expect(router.compactColumn == .sidebar)

    router.open(checklistID: "a")
    #expect(router.compactColumn == .detail)
  }

  @Test("going back to the sidebar closes the checklist; the split view's own .detail changes nothing")
  func compactColumnWritesSelection() {
    let router = Router()
    router.open(checklistID: "a")
    router.compactColumn = .detail
    #expect(router.selectedChecklistID == "a")

    router.compactColumn = .sidebar
    #expect(router.selectedChecklistID == nil)

    router.compactColumn = .detail
    #expect(router.selectedChecklistID == nil)
  }
}
