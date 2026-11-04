//
//  ToastView.swift
//  checklists
//

import SwiftUI

/// The toast card itself, with no opinion about where it sits (`ToastPresenterModifier`) or how
/// long it lives (`ToastPresenter`).
///
/// On `darkBlueGray`: it differs from the page in both appearances, so it separates from the content underneath without leaning on its shadow.
struct ToastView: View {
  let toast: Toast
  /// Tapping the card anywhere but the action button dismisses it, whatever kind of toast it is.
  /// Deliberately never the action: a thumb that misses Undo must not perform it.
  let onDismiss: () -> Void
  let onAction: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private static let dismissActionTitle = String(
    localized: "toast.accessibilityAction.dismiss",
    defaultValue: "Dismiss",
    comment: """
    VoiceOver action on a short message card shown at the bottom of the screen, such as "Copied \
    items to Groceries". Removes the card. Under VoiceOver the card stays until removed, so this \
    is how a VoiceOver user clears it. Keep it to one word if your language allows.
    """,
  )

  private static let dismissHint = String(
    localized: "toast.accessibilityHint",
    defaultValue: "Dismisses the message.",
    comment: """
    VoiceOver hint read after a short message card at the bottom of the screen, such as "Copied \
    items to Groceries". Says what activating the card does: it goes away. Describe the result, \
    not the gesture.
    """,
  )

  /// Beside the message at standard sizes; under it at accessibility sizes, where a side-by-side
  /// action leaves the message a column a few letters wide.
  private var layout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 4))
      : AnyLayout(HStackLayout(spacing: 12))
  }

  var body: some View {
    layout {
      // A status message, not a button: VoiceOver reads it with the dismiss hint and actions below.
      // swiftlint:disable:next accessibility_trait_for_button
      HStack(spacing: 12) {
        Image(systemName: toast.style.symbolName)
          .font(.headline)
          .foregroundStyle(toast.style.tint)
          // Decorative: the message already says what happened.
          .accessibilityHidden(true)

        Text(toast.message)
          .font(.subheadline)
          .foregroundStyle(Colors.panelForegroundColor)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      // On this group rather than the whole card. A gesture on an ancestor of the button fires
      // *as well as* the button, and its dismissal lands after the handler — clearing any toast
      // the handler raised.
      .contentShape(Rectangle())
      .onTapGesture(perform: onDismiss)
      // Under VoiceOver a toast stays until dismissed, so the tap above needs spoken equivalents:
      // a double-tap, the Actions rotor and the escape scrub. The action button stays its own
      // element, outside this group.
      .accessibilityElement(children: .combine)
      .accessibilityHint(Self.dismissHint)
      .accessibilityAction(.default, onDismiss)
      .accessibilityAction(named: Self.dismissActionTitle, onDismiss)
      .accessibilityAction(.escape, onDismiss)

      if let action = toast.action {
        Button(action: onAction) {
          Text(action.title)
            .font(.subheadline.weight(.semibold))
            // 44pt so the button clears the touch-target minimum even at the smallest text size.
            .frame(minWidth: 44, minHeight: 44)
        }
        // Not the accent colour: it is too close to the card's blue to read. The weight is what
        // marks this as the action.
        .tint(Colors.panelForegroundColor)
      }
    }
    .padding(.leading, 16)
    // 8 beside a side-by-side action, whose 44pt minimum width already leaves room around "Undo".
    .padding(.trailing, toast.action == nil || dynamicTypeSize.isAccessibilitySize ? 16 : 8)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Colors.darkBlueGrayColor)
        .shadow(color: Colors.shadowColor.opacity(0.4), radius: 3, x: 0, y: 2),
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
        action: ToastAction(title: previewMessage("Undo")) {},
      ),
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
        action: ToastAction(title: previewMessage("Undo")) {},
      ),
    ) {} onAction: {}
      .padding(16)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Colors.defaultBackgroundColor)
  }
#endif
