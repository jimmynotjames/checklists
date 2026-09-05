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

  init(underlying: any Error) {
    let nsError = underlying as NSError
    errorDomain = nsError.domain
    errorCode = nsError.code
  }

  /// Terse, PII-free identifier for logs and the feedback mail body.
  var diagnosticDescription: String {
    "\(errorDomain) \(errorCode)"
  }
}
