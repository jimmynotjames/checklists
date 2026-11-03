//
//  FeedbackMail.swift
//  checklists
//

import Foundation

/// The pre-addressed feedback email that Settings and the database-failure screen both open.
///
/// Handed to Mail as a `mailto:` URL rather than composed in-app, so the person's own mail account
/// sends it and the app needs no mail entitlement or composer fallback.
nonisolated enum FeedbackMail {
  static let address = "jimmyho.appfeedback@gmail.com"

  static func url(subject: String, body: String) -> URL? {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = address
    components.queryItems = [
      URLQueryItem(name: "subject", value: subject),
      URLQueryItem(name: "body", value: body),
    ]
    return components.url
  }
}
