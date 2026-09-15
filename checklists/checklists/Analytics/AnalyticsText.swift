//
//  AnalyticsText.swift
//  checklists
//

/// Text handling for property values.
///
/// nonisolated on the type: see AnalyticsEvent.
nonisolated enum AnalyticsText {
  /// The longest string sent as a property value.
  ///
  /// The backend's own limit is 255 characters; 127 is half that, which leaves headroom in case a
  /// limit is ever counted in UTF-8 bytes rather than characters.
  static let maximumLength = 127

  /// Truncates a user-supplied string before it is sent. `checklist_name` is the only caller.
  ///
  /// Cuts on a `Character` boundary, so a multi-scalar grapheme — a ZWJ emoji sequence, say — is
  /// never split into a broken pair.
  static func truncated(_ string: String) -> String {
    String(string.prefix(maximumLength))
  }
}
