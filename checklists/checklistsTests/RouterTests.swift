//
//  RouterTests.swift
//  checklistsTests
//

@testable import checklists
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

  @Test("the stack path mirrors the selection")
  func stackPathReadsSelection() {
    let router = Router()
    #expect(router.stackPath.isEmpty)

    router.open(checklistID: "a")
    #expect(router.stackPath == [.checklist(id: "a")])
  }

  @Test("a push or pop through the stack path updates the selection")
  func stackPathWritesSelection() {
    let router = Router()
    router.stackPath = [.checklist(id: "a")]
    #expect(router.selectedChecklistID == "a")

    router.stackPath = []
    #expect(router.selectedChecklistID == nil)
  }
}
