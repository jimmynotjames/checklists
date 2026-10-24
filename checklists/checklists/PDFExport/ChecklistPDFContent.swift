//
//  ChecklistPDFContent.swift
//  checklists
//

import UIKit

/// Lays an exported checklist out as one attributed string, which the renderer flows across pages.
///
/// Spare and minimal in the system font: the name, the chosen date, the Header, a divider, then
/// the checklist exactly as it stands. Colours are fixed rather than the app's palette, because a
/// PDF is printed and forwarded, not shown in the app's appearance; dark grey rather than a light
/// grey keeps secondary text readable on paper.
enum ChecklistPDFContent {
  static let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
  static let dateFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
  static let secondaryFont = UIFont.systemFont(ofSize: 12)
  static let itemFont = UIFont.systemFont(ofSize: 14)
  static let primaryColor = UIColor.black
  /// `nonisolated` so the page footer, drawn by an unisolated UIKit renderer, can share it.
  nonisolated static let secondaryColor = UIColor(white: 0.3, alpha: 1)

  /// The checkbox and the gap after it, which wrapped item lines and item notes indent by so they
  /// line up under the item's text.
  private static let checkboxSide: CGFloat = 14
  private static let checkboxGap: CGFloat = 8
  private static var itemIndent: CGFloat {
    checkboxSide + checkboxGap
  }

  /// - Parameter contentWidth: the printable width, which the divider spans.
  static func attributedString(for snapshot: ChecklistPDFSnapshot, contentWidth: CGFloat) -> NSAttributedString {
    let direction: NSWritingDirection = snapshot.isRightToLeft ? .rightToLeft : .leftToRight
    let result = NSMutableAttributedString()

    result.append(paragraph(snapshot.title, font: titleFont, color: primaryColor, direction: direction, spacingAfter: 4))
    result.append(paragraph(dateString(for: snapshot), font: dateFont, color: primaryColor, direction: direction, spacingAfter: 12))
    if !snapshot.header.isEmpty {
      result.append(paragraph(snapshot.header, font: secondaryFont, color: secondaryColor, direction: direction, spacingAfter: 12))
    }
    result.append(divider(width: contentWidth, direction: direction))
    if let notes = snapshot.checklistNotes {
      result.append(paragraph(notes, font: secondaryFont, color: secondaryColor, direction: direction, spacingAfter: 12))
    }
    for row in snapshot.rows {
      result.append(item(row, direction: direction))
    }
    return result
  }

  /// "Friday, 23 October 2026 at 2:15 PM PDT" in the person's own language and order: no label,
  /// because the date is the one the person chose for the record, not necessarily when it was made.
  static func dateString(for snapshot: ChecklistPDFSnapshot) -> String {
    let formatter = DateFormatter()
    formatter.locale = snapshot.locale
    formatter.timeZone = snapshot.timeZone
    formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMMyjmmz")
    return formatter.string(from: snapshot.date)
  }

  // MARK: - Pieces

  private static func paragraphStyle(direction: NSWritingDirection, spacingAfter: CGFloat, indent: CGFloat = 0, firstLineIndent: CGFloat? = nil) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    // Natural, with an explicit base direction, so a right-to-left page is right-aligned and its
    // indents measure from the right.
    style.alignment = .natural
    style.baseWritingDirection = direction
    style.paragraphSpacing = spacingAfter
    style.headIndent = indent
    style.firstLineHeadIndent = firstLineIndent ?? indent
    return style
  }

  /// Text with its own line breaks kept: each is a line break inside one paragraph, so spacing
  /// only follows the whole block.
  private static func paragraph(_ text: String, font: UIFont, color: UIColor, direction: NSWritingDirection, spacingAfter: CGFloat, indent: CGFloat = 0) -> NSAttributedString {
    NSAttributedString(
      string: text.replacing("\n", with: "\u{2028}") + "\n",
      attributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraphStyle(direction: direction, spacingAfter: spacingAfter, indent: indent),
      ],
    )
  }

  /// A thin rule across the page, as an attachment so it flows with the text rather than being
  /// drawn at a fixed position.
  private static func divider(width: CGFloat, direction: NSWritingDirection) -> NSAttributedString {
    let attachment = NSTextAttachment()
    attachment.image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
      secondaryColor.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    attachment.bounds = CGRect(x: 0, y: 0, width: width, height: 0.75)
    let line = NSMutableAttributedString(attachment: attachment)
    line.append(NSAttributedString(string: "\n"))
    line.addAttribute(.paragraphStyle, value: paragraphStyle(direction: direction, spacingAfter: 14), range: NSRange(location: 0, length: line.length))
    return line
  }

  /// The checkbox, the name with wrapped lines hanging under its own first word, then the item's
  /// notes indented to the same line. No strikethrough on checked items, matching the app.
  private static func item(_ row: ChecklistPDFSnapshot.Row, direction: NSWritingDirection) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let hasNotes = row.notes != nil
    let style = paragraphStyle(direction: direction, spacingAfter: hasNotes ? 2 : 8, indent: itemIndent, firstLineIndent: 0)

    let line = NSMutableAttributedString(attachment: checkbox(isChecked: row.isChecked))
    // A fixed-width gap rather than spaces, so names line up whatever the font's space width.
    let gap = NSTextAttachment()
    gap.bounds = CGRect(x: 0, y: 0, width: checkboxGap, height: 0)
    line.append(NSAttributedString(attachment: gap))
    line.append(NSAttributedString(string: row.name.replacing("\n", with: "\u{2028}") + "\n"))
    line.addAttributes(
      [.font: itemFont, .foregroundColor: primaryColor, .paragraphStyle: style],
      range: NSRange(location: 0, length: line.length),
    )
    result.append(line)

    if let notes = row.notes {
      result.append(paragraph(notes, font: secondaryFont, color: secondaryColor, direction: direction, spacingAfter: 8, indent: itemIndent))
    }
    return result
  }

  /// The app's own checkbox glyphs, squares rather than circles, centred on the item's capitals.
  private static func checkbox(isChecked: Bool) -> NSTextAttachment {
    let side = checkboxSide
    let attachment = NSTextAttachment()
    attachment.image = checkboxImage(isChecked: isChecked, side: side)
    attachment.bounds = CGRect(x: 0, y: (itemFont.capHeight - side) / 2, width: side, height: side)
    return attachment
  }

  /// Flattened to a bitmap first: the print formatter fills a symbol image's whole box with the
  /// text colour, so an unflattened checkbox prints as a solid square whether it is ticked or not.
  /// Drawn at several times its printed size so it stays sharp on paper.
  private static func checkboxImage(isChecked: Bool, side: CGFloat) -> UIImage? {
    let configuration = UIImage.SymbolConfiguration(pointSize: side, weight: .regular)
    guard let symbol = UIImage(systemName: isChecked ? "checkmark.square.fill" : "square", withConfiguration: configuration)?
      .withTintColor(primaryColor, renderingMode: .alwaysOriginal) else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 8
    format.opaque = false
    let size = CGSize(width: side, height: side)
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
      // Fitted into the square, keeping the symbol's own proportions.
      let scale = min(side / symbol.size.width, side / symbol.size.height)
      let drawn = CGSize(width: symbol.size.width * scale, height: symbol.size.height * scale)
      symbol.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2, width: drawn.width, height: drawn.height))
    }
  }
}
