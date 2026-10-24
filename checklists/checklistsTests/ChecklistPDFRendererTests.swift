//
//  ChecklistPDFRendererTests.swift
//  checklistsTests
//

@testable import checklists
import Foundation
import PDFKit
import Testing

/// Covers the PDF the renderer writes: pagination, paper, title metadata and the page footer.
/// PDFKit reads the result back; the app itself never uses it.
@Suite("Checklist PDF renderer")
struct ChecklistPDFRendererTests {
  private func snapshot(header: String = "", paperSize: PaperSize = .a4) -> ChecklistPDFSnapshot {
    ChecklistPDFSnapshot(
      title: "Quality check",
      date: Date(timeIntervalSince1970: 1_792_756_800),
      header: header,
      checklistNotes: nil,
      rows: [.init(name: "Shut off water", notes: nil, isChecked: true)],
      isRightToLeft: false,
      paperSize: paperSize,
    )
  }

  private func document(_ snapshot: ChecklistPDFSnapshot) throws -> PDFDocument {
    try #require(PDFDocument(data: ChecklistPDFRenderer.render(snapshot)))
  }

  @Test("a short checklist fits on one page")
  func shortChecklistIsOnePage() throws {
    #expect(try document(snapshot()).pageCount == 1)
  }

  @Test("a Header at the character limit flows onto further pages")
  func longHeaderPaginates() throws {
    let header = String(repeating: "Acme Plumbing Ltd, licence 12345. ", count: HeaderText.characterLimit / 34)

    #expect(try document(snapshot(header: header)).pageCount > 5)
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

  @Test("every page carries its page number and the total")
  func footerOnEveryPage() throws {
    let header = String(repeating: "Acme Plumbing Ltd, licence 12345. ", count: 400)
    let pdf = try document(snapshot(header: header))
    let pageCount = pdf.pageCount

    for index in 0 ..< pageCount {
      let text = try #require(pdf.page(at: index)?.string)
      #expect(text.contains(ChecklistPDFRenderer.footerText(page: index + 1, of: pageCount)))
    }
  }
}
