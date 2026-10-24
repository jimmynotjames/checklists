//
//  ChecklistPDFRendererTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import PDFKit
import Testing

/// Covers the PDF the renderer writes: pagination, paper and title metadata.
/// PDFKit reads the result back; the app itself never uses it.
@Suite("Checklist PDF renderer")
struct ChecklistPDFRendererTests {
  private func snapshot(notes: String? = nil, paperSize: PaperSize = .a4) -> ChecklistPDFSnapshot {
    ChecklistPDFSnapshot(
      title: "Quality check",
      checklistNotes: notes,
      rows: [.init(name: "Shut off water", notes: nil, isChecked: true)],
      isRightToLeft: false,
      paperSize: paperSize,
    )
  }

  private static let longNotes = String(repeating: "Acme Plumbing Ltd, licence 12345. ", count: 900)

  private func document(_ snapshot: ChecklistPDFSnapshot) throws -> PDFDocument {
    try #require(PDFDocument(data: ChecklistPDFRenderer.render(snapshot)))
  }

  @Test("a short checklist fits on one page")
  func shortChecklistIsOnePage() throws {
    #expect(try document(snapshot()).pageCount == 1)
  }

  @Test("long notes flow onto further pages")
  func longNotesPaginate() throws {
    #expect(try document(snapshot(notes: Self.longNotes)).pageCount > 5)
  }

  @Test("the PDF's title is the checklist name")
  func titleMetadataIsTheName() throws {
    let attributes = try document(snapshot()).documentAttributes
    #expect(attributes?[PDFDocumentAttribute.titleAttribute] as? String == "Quality check")
    #expect(attributes?[PDFDocumentAttribute.authorAttribute] == nil)
  }

  @Test("pages are the paper size picked for the region", arguments: [PaperSize.a4, .letter])
  func pagesMatchThePaper(paperSize: PaperSize) throws {
    let page = try #require(try document(snapshot(paperSize: paperSize)).page(at: 0))
    let bounds = page.bounds(for: .mediaBox)

    #expect(abs(bounds.width - paperSize.pageSize.width) < 1)
    #expect(abs(bounds.height - paperSize.pageSize.height) < 1)
  }
}
