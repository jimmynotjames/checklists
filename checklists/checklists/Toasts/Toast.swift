//
//  Toast.swift
//  checklists
//

import Foundation
import SwiftUI

/// One transient confirmation message.
///
/// Identity is per-instance rather than per-message: `ToastPresenter` uses `id` to tell a
/// dismissal that belongs to the toast still on screen from one whose toast was already replaced,
/// so two toasts carrying the same words are still two toasts.
///
/// `message` is a `LocalizedStringResource`, not a `String`, because `check_source_strings.py`
/// does not inspect custom initializers — a `String` would let untranslated copy reach the
/// screen without `make i18n-check` noticing.
nonisolated struct Toast: Identifiable {
  let id = UUID()
  let message: LocalizedStringResource
  let style: ToastStyle
  /// Present only when there is something to do about the message. Its presence lengthens the
  /// dwell, because reading, reaching and tapping does not fit in the default.
  let action: ToastAction?

  init(message: LocalizedStringResource, style: ToastStyle = .info, action: ToastAction? = nil) {
    self.message = message
    self.style = style
    self.action = action
  }
}

/// A single trailing button on a toast — the shape an Undo needs.
nonisolated struct ToastAction {
  let title: LocalizedStringResource
  let handler: @MainActor () -> Void
}

/// What a toast is about. Only the leading symbol and its tint change — the card itself stays the
/// same so a toast never reads as an alert.
nonisolated enum ToastStyle {
  case info
  case success
  case warning
  case error

  var symbolName: String {
    switch self {
    case .info: "info.circle.fill"
    case .success: "checkmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .error: "xmark.octagon.fill"
    }
  }

  /// `@MainActor` because `Colors` is — the palette is shared with the UIKit screen, where it is
  /// isolated like everything else in the target.
  @MainActor var tint: Color {
    switch self {
    case .info: Colors.defaultBackgroundColor
    case .success: Colors.successColor
    case .warning: Colors.warningColor
    case .error: Colors.destructiveColor
    }
  }
}
