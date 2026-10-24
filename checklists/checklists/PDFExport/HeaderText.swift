//
//  HeaderText.swift
//  checklists
//

import Foundation

/// Rules for the export sheet's Header: the free text printed at the top of the PDF, and what a
/// Saved Header is made from.
nonisolated enum HeaderText {
  /// About ten single-spaced pages. Counted in `Character`s, Swift's default, so an emoji counts
  /// as one.
  static let characterLimit = 30000

  static func capped(_ text: String) -> String {
    String(text.prefix(characterLimit))
  }

  /// What is saved, compared and printed, so "Acme" and "Acme⏎" are one Saved Header.
  static func normalized(_ text: String) -> String {
    text.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// The text that inserting `saved` adds to the end of `current`.
  ///
  /// Always appended, never overwriting or inserted at the cursor: appending keeps tap order, so a
  /// Header can be built from pieces, and never destroys what was typed. A line break goes first
  /// unless the field is empty or already ends in one, so the Saved Header starts on its own line.
  /// Cut short at the limit; empty when the field is already full.
  static func appendix(inserting saved: String, into current: String) -> String {
    let separator = current.isEmpty || current.last?.isNewline == true ? "" : "\n"
    let room = characterLimit - current.count
    guard room > 0 else { return "" }
    return String((separator + saved).prefix(room))
  }
}
