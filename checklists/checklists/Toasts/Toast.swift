//
//  Toast.swift
//  checklists
//

import Foundation
import SwiftUI

/// One transient message: a confirmation, or a failure the person cannot act on in place.
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
    case .info: Colors.panelForegroundColor
    case .success: Colors.successColor
    case .warning: Colors.warningColor
    case .error: Colors.destructiveColor
    }
  }
}

/// Shown by `SaveFailureNotifier`, from every screen.
extension Toast {
  static var saveFailed: Toast {
    Toast(
      message: LocalizedStringResource(
        "toast.saveFailed",
        defaultValue: "Save failed. Your device may be low on storage.",
        comment: """
        Error toast shown when a change could not be written to the device. Full storage is the \
        likely cause but not a certain one — a damaged database fails the same way — so the \
        second sentence must stay a guess ("may"), never a statement of fact. Appears briefly at \
        the bottom of the screen with no button. Keep it short; it can appear after any edit \
        (adding, ticking, renaming, deleting).
        """,
      ),
      style: .error,
    )
  }
}

/// Shown by `ChecklistScreen` as the checklist on screen closes because another device deleted it.
extension Toast {
  static var checklistDeletedElsewhere: Toast {
    Toast(
      message: LocalizedStringResource(
        "toast.checklistDeletedElsewhere",
        defaultValue: "This checklist was deleted on another device.",
        comment: """
        Info toast shown as an open checklist closes by itself, because the same checklist was \
        deleted on another of the person's devices and the deletion synced. Explains why the screen \
        went away. Appears briefly at the bottom of the list of checklists, with no button.
        """,
      ),
    )
  }
}

/// Shown by `CopyCheckedItemsView` when it closes because nothing is checked any more.
extension Toast {
  static var noCheckedItemsLeft: Toast {
    Toast(
      message: LocalizedStringResource(
        "toast.copyCheckedItems.nothingChecked",
        defaultValue: "No checked items left to copy or move.",
        comment: """
        Info toast shown when the Copy or Move Checked Items sheet closes after the person picks a \
        destination, because the items were unchecked in the meantime, for example on another \
        device. "Left" signals that there were checked items when the sheet opened. Appears briefly \
        at the bottom of the screen, with no button.
        """,
      ),
    )
  }
}

/// Shown by `ChecklistScreen` when Export as PDF… could not make or write the PDF.
extension Toast {
  static var pdfExportFailed: Toast {
    Toast(
      message: LocalizedStringResource(
        "toast.pdfExportFailed",
        defaultValue: "Couldn't create the PDF.",
        comment: """
        Error toast shown on a checklist's screen when the Export as PDF… menu entry could not \
        make the PDF file of the checklist, for example because the device is out of storage. \
        Appears briefly at the bottom of the screen, with no button.
        """,
      ),
      style: .error,
    )
  }
}

/// Shown by `ChecklistScreen` when a ⋯ menu entry that acts on the checked items is tapped with
/// nothing checked.
extension Toast {
  static var noCheckedItems: Toast {
    Toast(
      message: LocalizedStringResource(
        "checklist.menu.copyCheckedItems.noCheckedItems",
        defaultValue: "No checked items.",
        comment: """
        Info toast shown on a checklist's screen when the Copy Checked Items to…, Move Checked \
        Items to… or Delete Checked Items menu entry is tapped with nothing ticked. It says why \
        nothing happened. Echo the wording of those entries: it should read as "there are none of \
        the thing that entry acts on", so reuse their word for checked items rather than picking a \
        synonym. Appears briefly at the bottom of the screen, with no button. Keep it to a few words.
        """,
      ),
    )
  }
}
