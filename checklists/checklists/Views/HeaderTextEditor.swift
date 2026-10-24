//
//  HeaderTextEditor.swift
//  checklists
//

import SwiftUI
import UIKit

/// The export sheet's multi-line Header field: a `UITextView`, because inserting a Saved Header has
/// to append through the text view's own editing path.
///
/// `TextEditor` offers no equivalent. Setting its text from code replaces the whole string, which
/// can lose the undo history, and it gives no dependable way to scroll a long field to text added
/// at its end.
struct HeaderTextEditor: UIViewRepresentable {
  @Binding var text: String
  let proxy: HeaderEditorProxy
  let accessibilityLabel: String

  /// Tall enough to show a typical Header whole, short enough that a long one scrolls inside the
  /// field rather than pushing the rest of the sheet away.
  private static let minimumLines: CGFloat = 4
  private static let maximumLines: CGFloat = 10

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.font = UIFont.preferredFont(forTextStyle: .body)
    textView.adjustsFontForContentSizeCategory = true
    textView.textColor = Colors.primaryText
    textView.backgroundColor = .clear
    // Flush with the row's own insets, as a `TextField` sits in a `Form`.
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.isScrollEnabled = true
    textView.text = text
    textView.accessibilityLabel = accessibilityLabel
    textView.accessibilityIdentifier = "exportPDF.header"
    proxy.textView = textView
    return textView
  }

  /// Leaves the text alone while the field is being typed into: writing it back would reset the
  /// cursor and the undo history for a value that came from the field in the first place.
  func updateUIView(_ textView: UITextView, context: Context) {
    context.coordinator.text = $text
    if textView.text != text, !textView.isFirstResponder {
      textView.text = text
    }
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView textView: UITextView, context _: Context) -> CGSize? {
    guard let width = proposal.width, width.isFinite else { return nil }
    let lineHeight = textView.font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
    let fitting = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
    let height = min(max(fitting, lineHeight * Self.minimumLines), lineHeight * Self.maximumLines)
    return CGSize(width: width, height: ceil(height))
  }

  @MainActor
  final class Coordinator: NSObject, UITextViewDelegate {
    var text: Binding<String>

    init(text: Binding<String>) {
      self.text = text
    }

    func textViewDidChange(_ textView: UITextView) {
      text.wrappedValue = textView.text
      // Grows the field with its text, up to its maximum height.
      textView.invalidateIntrinsicContentSize()
    }

    /// Holds the field to `HeaderText.characterLimit`. An edit that would pass it goes in cut to
    /// fit, so a long paste keeps its first 30,000 characters rather than being refused outright.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
      let current = textView.text ?? ""
      guard let replaced = Range(range, in: current) else { return true }
      let room = HeaderText.characterLimit - (current.count - current[replaced].count)
      guard replacement.count > room else { return true }
      guard room > 0,
            let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
            let end = textView.position(from: start, offset: range.length),
            let textRange = textView.textRange(from: start, to: end) else { return false }
      // Through `UITextInput`, so the shortened edit is one step in the field's undo history.
      textView.replace(textRange, withText: String(replacement.prefix(room)))
      textViewDidChange(textView)
      return false
    }
  }
}

/// How the export sheet reaches into the Header field to insert a Saved Header.
@MainActor
final class HeaderEditorProxy {
  weak var textView: UITextView?

  /// Appends `saved` per `HeaderText.appendix(inserting:into:)`, then puts the cursor after it and
  /// scrolls it into view: in a long field, an insertion out of sight looks like nothing happened.
  /// The keyboard stays as it was.
  func append(_ saved: String) {
    guard let textView else { return }
    let appendix = HeaderText.appendix(inserting: saved, into: textView.text ?? "")
    guard !appendix.isEmpty,
          let end = textView.textRange(from: textView.endOfDocument, to: textView.endOfDocument) else { return }
    // Through `UITextInput` rather than assigning `text`, so Undo can take it back out.
    textView.replace(end, withText: appendix)
    let endRange = NSRange(location: (textView.text as NSString).length, length: 0)
    textView.selectedRange = endRange
    textView.scrollRangeToVisible(endRange)
    // A programmatic edit does not always reach the delegate; this keeps the binding in step.
    textView.delegate?.textViewDidChange?(textView)
  }
}
