//
//  PDFFileName.swift
//  checklists
//

import Foundation

/// The exported file's name, which is what the recipient sees on the attachment and in Files.
nonisolated enum PDFFileName {
  /// Below the 255-byte limit most file systems put on a name, leaving room for the date and
  /// extension.
  private static let maxTitleBytes = 200

  /// `<title> <yyyy-MM-dd>.pdf`, dated with the date the person chose, not the export time.
  static func make(title: String, date: Date, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    // Fixed, not localized: a sortable machine date reads the same in every language.
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return "\(sanitize(title)) \(formatter.string(from: date)).pdf"
  }

  /// Makes a checklist name safe as a file name: `/` and `:` are path separators on Apple file
  /// systems, a leading dot would hide the file, and a name can run longer than a file name may.
  static func sanitize(_ title: String) -> String {
    var cleaned = String(title.map { character -> Character in
      if character == "/" || character == ":" {
        return "-"
      }
      if character.isNewline || character.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
        return " "
      }
      return character
    })
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    while cleaned.hasPrefix(".") {
      cleaned.removeFirst()
    }
    // Cut on a `Character`, so a multi-byte letter or emoji is never split.
    while cleaned.utf8.count > maxTitleBytes {
      cleaned.removeLast()
    }
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? CommonStrings.defaultChecklistName : cleaned
  }
}
