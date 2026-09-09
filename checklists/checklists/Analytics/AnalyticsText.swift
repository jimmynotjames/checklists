//
//  AnalyticsText.swift
//  checklists
//

/// Text handling for property values.
enum AnalyticsText {
  /// The longest string sent as a property value.
  ///
  /// 127 characters was chosen against Flurry's 255-character parameter limit, halved in case the
  /// limit was counted in UTF-8 bytes rather than characters. Mixpanel's limit is also 255, so the
  /// value carries over unchanged.
  nonisolated static let maximumLength = 127

  /// Truncates a user-supplied or error string before it is sent.
  ///
  /// Cuts on a `Character` boundary, so a multi-scalar grapheme — a ZWJ emoji sequence, say — is
  /// never split into a broken pair.
  nonisolated static func truncated(_ string: String) -> String {
    String(string.prefix(maximumLength))
  }
}
