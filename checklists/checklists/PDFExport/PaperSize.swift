//
//  PaperSize.swift
//  checklists
//

import CoreGraphics

/// The paper an exported PDF is laid out on, picked from the person's region with no setting.
nonisolated enum PaperSize: Equatable {
  case letter
  case a4

  /// In PostScript points, 72 to the inch.
  var pageSize: CGSize {
    switch self {
    case .letter: CGSize(width: 612, height: 792)
    case .a4: CGSize(width: 595.28, height: 841.89)
    }
  }

  /// iOS exposes no regional paper default: `UIPrintPaper` only chooses among a printer's papers,
  /// and the measurement system is a different question (metric Canada prints on Letter). This is
  /// CLDR's `paperSize` supplemental data, whose US-Letter list is short and rarely changes.
  static let letterRegions: Set<String> = ["BZ", "CA", "CL", "CO", "CR", "GT", "MX", "NI", "PA", "PH", "PR", "SV", "US", "VE"]

  /// A4 for every other region, and when the region is unknown, since most of the world uses it.
  static func forRegion(_ regionCode: String?) -> PaperSize {
    guard let regionCode, letterRegions.contains(regionCode.uppercased()) else { return .a4 }
    return .letter
  }
}
