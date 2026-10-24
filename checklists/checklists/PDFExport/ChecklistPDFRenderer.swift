//
//  ChecklistPDFRenderer.swift
//  checklists
//

import UIKit

/// Turns a snapshot into PDF data, paginated.
///
/// UIKit's print formatter does the pagination, so long notes or a long checklist flow onto as
/// many pages as they need with no layout code here. SwiftUI's `ImageRenderer` draws a single page,
/// and PDFKit only reads PDFs, so neither can lay one out.
enum ChecklistPDFRenderer {
  /// Three-quarters of an inch on every side.
  static let margin: CGFloat = 54

  static func render(_ snapshot: ChecklistPDFSnapshot) -> Data {
    let paperRect = CGRect(origin: .zero, size: snapshot.paperSize.pageSize)
    let printableRect = paperRect.insetBy(dx: margin, dy: margin)
    let pageRenderer = PageRenderer(paperRect: paperRect, printableRect: printableRect)
    let text = ChecklistPDFContent.attributedString(for: snapshot, contentWidth: printableRect.width)
    pageRenderer.addPrintFormatter(UISimpleTextPrintFormatter(attributedText: text), startingAtPageAt: 0)

    let format = UIGraphicsPDFRendererFormat()
    // The title only: no author or creator, which would name the device's owner.
    format.documentInfo = [kCGPDFContextTitle as String: snapshot.title]
    return UIGraphicsPDFRenderer(bounds: paperRect, format: format).pdfData { context in
      let pageCount = pageRenderer.numberOfPages
      pageRenderer.prepare(forDrawingPages: NSRange(location: 0, length: pageCount))
      for page in 0 ..< pageCount {
        context.beginPage()
        pageRenderer.drawPage(at: page, in: context.pdfContextBounds)
      }
    }
  }

  /// `UIPrintPageRenderer` reads its paper from a print job; outside one, the only way to give it
  /// paper is to override the getters. `nonisolated` to match the superclass, which UIKit leaves
  /// unisolated.
  nonisolated private final class PageRenderer: UIPrintPageRenderer {
    private let paper: CGRect
    private let printable: CGRect

    init(paperRect: CGRect, printableRect: CGRect) {
      paper = paperRect
      printable = printableRect
      super.init()
    }

    override var paperRect: CGRect {
      paper
    }

    override var printableRect: CGRect {
      printable
    }
  }
}
