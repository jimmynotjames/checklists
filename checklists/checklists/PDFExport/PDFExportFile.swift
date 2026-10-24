//
//  PDFExportFile.swift
//  checklists
//

import Foundation

/// The temporary file the share sheet is handed. Nothing about an export is kept: the file goes as
/// soon as the share sheet closes.
nonisolated enum PDFExportFile {
  static let rootDirectory = FileManager.default.temporaryDirectory.appending(path: "PDFExport", directoryHint: .isDirectory)

  /// In a folder of its own, so the file keeps the readable name the recipient sees and `remove`
  /// takes away exactly one export.
  ///
  /// Clears out earlier exports first: a crash while the share sheet was up would otherwise leave
  /// one behind.
  static func write(_ data: Data, fileName: String) throws -> URL {
    let fileManager = FileManager.default
    try? fileManager.removeItem(at: rootDirectory)
    let folder = rootDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appending(path: fileName, directoryHint: .notDirectory)
    try data.write(to: url, options: .atomic)
    return url
  }

  static func remove(_ url: URL) {
    try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
  }
}
