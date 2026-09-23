//
//  ToastView.swift
//  checklists
//

import SwiftUI

/// The toast card itself, with no opinion about where it sits (`ToastPresenterModifier`) or how
/// long it lives (`ToastPresenter`).
///
/// Dark on a light-only app, matching `MainMenuView`'s surface: it separates from the content
/// underneath on its own, where a light card would lean entirely on its shadow to do that.
struct ToastView: View {
  let toast: Toast
  /// Tapping the card anywhere but the action button dismisses it, whatever kind of toast it is.
  /// Deliberately never the action: a thumb that misses Undo must not perform it.
  let onDismiss: () -> Void
  let onAction: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 12) {
        Image(systemName: toast.style.symbolName)
          .font(.headline)
          .foregroundStyle(toast.style.tint)
          // Decorative: the message already says what happened.
          .accessibilityHidden(true)

        Text(toast.message)
          .font(.subheadline)
          .foregroundStyle(Colors.defaultBackgroundColor)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      // On this group rather than the whole card. A gesture on an ancestor of the button fires
      // *as well as* the button, and its dismissal lands after the handler — clearing any toast
      // the handler raised.
      .contentShape(Rectangle())
      .onTapGesture(perform: onDismiss)

      if let action = toast.action {
        Button(action: onAction) {
          Text(action.title)
            .font(.subheadline.weight(.semibold))
            // 44pt so the button clears the touch-target minimum even at the smallest text size.
            .frame(minWidth: 44, minHeight: 44)
        }
        // Not the accent colour: it is rgb(55,130,136) against a rgb(51,110,145) card, about
        // 1.2:1. The weight is what marks this as the action, the way `MainMenuView`'s rows do.
        .tint(Colors.defaultBackgroundColor)
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, toast.action == nil ? 16 : 8)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Colors.darkBlueGrayColor)
        // The floating-button treatment from `ChecklistsView`, so the two read as one system.
        .shadow(color: Colors.shadowColor.opacity(0.4), radius: 3, x: 0, y: 2)
    )
    // Locale-invariant handle so UI tests can wait a toast out rather than tapping through it.
    .accessibilityIdentifier("toast")
  }
}

#if DEBUG
  /// Built from a runtime string so no demo literal is extracted into `Localizable.xcstrings`.
  private func previewMessage(_ text: String) -> LocalizedStringResource {
    LocalizedStringResource(String.LocalizationValue(stringLiteral: text))
  }

  #Preview("Styles") {
    VStack(spacing: 12) {
      ToastView(toast: Toast(message: previewMessage("Copied items to Groceries"), style: .info)) {} onAction: {}
      ToastView(toast: Toast(message: previewMessage("Checklist duplicated"), style: .success)) {} onAction: {}
      ToastView(toast: Toast(message: previewMessage("Checklist deleted"), style: .warning)) {} onAction: {}
      ToastView(toast: Toast(message: previewMessage("Could not save"), style: .error)) {} onAction: {}
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Colors.defaultBackgroundColor)
  }

  #Preview("With an action") {
    ToastView(
      toast: Toast(
        message: previewMessage("Checklist deleted"),
        style: .warning,
        action: ToastAction(title: previewMessage("Undo")) {}
      )
    ) {} onAction: {}
      .padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Colors.defaultBackgroundColor)
  }

  #Preview("Long message") {
    ToastView(
      toast: Toast(
        message: previewMessage("Copied items to Saturday Morning Deep Clean Checklist"),
        style: .success,
        action: ToastAction(title: previewMessage("Undo")) {}
      )
    ) {} onAction: {}
      .padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Colors.defaultBackgroundColor)
  }
#endif
