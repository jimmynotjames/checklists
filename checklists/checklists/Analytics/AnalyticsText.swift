//
//  AnalyticsText.swift
//  checklists
//

/// Text handling for property values.
enum AnalyticsText {
  /// The longest string sent as a property value.
  ///
  /// The backend's own limit is 255 characters; 127 is half that, which leaves headroom in case a
  /// limit is ever counted in UTF-8 bytes rather than characters.
  nonisolated static let maximumLength = 127

  /// Truncates a user-supplied or error string before it is sent.
  ///
  /// Cuts on a `Character` boundary, so a multi-scalar grapheme — a ZWJ emoji sequence, say — is
  /// never split into a broken pair.
  nonisolated static func truncated(_ string: String) -> String {
    String(string.prefix(maximumLength))
  }
}
