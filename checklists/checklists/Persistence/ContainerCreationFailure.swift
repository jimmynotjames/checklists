//
//  ContainerCreationFailure.swift
//  checklists
//

import Foundation

/// The typed value carried when the persistent store cannot be opened at all.
///
/// Holds only an `NSError`'s `domain` and `code` — never `localizedDescription`, never `userInfo`
/// — so it is safe to log publicly and to drop into a feedback email. `userInfo` can serialise
/// arbitrary content, some of which may be the user's own data.
struct ContainerCreationFailure: Equatable, Hashable {
  let errorDomain: String
  let errorCode: Int

  init(errorDomain: String, errorCode: Int) {
    self.errorDomain = errorDomain
    self.errorCode = errorCode
  }

  /// `PersistenceError` is unwrapped first. It is a Swift struct, so `as NSError` would bridge it
  /// to `domain = "checklists.PersistenceError", code = 1` — collapsing every import and seed save
  /// failure into one bucket while the real domain and code sit in its own fields.
  init(underlying: any Error) {
    if let persistenceError = underlying as? PersistenceError {
      errorDomain = persistenceError.errorDomain
      errorCode = persistenceError.errorCode
      return
    }
    let nsError = underlying as NSError
    errorDomain = nsError.domain
    errorCode = nsError.code
  }

  /// Terse, PII-free identifier for logs and the feedback mail body.
  var diagnosticDescription: String {
    "\(errorDomain) \(errorCode)"
  }
}
