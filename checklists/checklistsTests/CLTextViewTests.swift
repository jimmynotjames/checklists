//
//  CLTextViewTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import Testing
import UIKit

/// Covers `CLTextView`'s placeholder-visibility rule (`updatePlaceholderLabel`, private, but its
/// effect on the placeholder label's `isHidden` is observable via the view hierarchy) and that the
/// `text`/`font` property overrides keep it in sync.
///
/// No Realm/DBManager involvement, so this doesn't need the in-memory-Realm save/restore pattern
/// the persistence-touching test classes use.
@Suite("CLTextView placeholder visibility")
struct CLTextViewTests {
  /// `placeholderLabel` is private; it's the view's only `UILabel` subview, added directly to the
  /// text view itself (`setUpSubviews()`), so it's reachable this way without touching anything
  /// else private.
  private func placeholderLabel(in textView: CLTextView) -> UILabel? {
    textView.subviews.compactMap { $0 as? UILabel }.first
  }

  @Test("placeholder is hidden when no placeholder text is set")
  func placeholderHiddenWhenNoPlaceholderTextSet() throws {
    let textView = CLTextView()
    let label = try #require(placeholderLabel(in: textView))
    #expect(label.isHidden)
  }

  @Test("placeholder is visible when text is empty and placeholder text is set")
  func placeholderVisibleWhenTextEmptyAndPlaceholderSet() throws {
    let textView = CLTextView()
    textView.placeholderText = "Notes"

    let label = try #require(placeholderLabel(in: textView))
    #expect(!label.isHidden)
    #expect(label.text == "Notes")
  }

  @Test("placeholder hides once text is set")
  func placeholderHiddenOnceTextIsSet() throws {
    let textView = CLTextView()
    textView.placeholderText = "Notes"
    let label = try #require(placeholderLabel(in: textView))
    #expect(!label.isHidden) // Precondition.

    textView.text = "hello"

    #expect(label.isHidden)
  }

  @Test("placeholder reappears when text is cleared again")
  func placeholderReappearsWhenTextClearedAgain() throws {
    let textView = CLTextView()
    textView.placeholderText = "Notes"
    textView.text = "hello"
    let label = try #require(placeholderLabel(in: textView))
    #expect(label.isHidden) // Precondition.

    textView.text = ""

    #expect(!label.isHidden)
  }

  @Test("an empty placeholder string is treated as no placeholder")
  func emptyPlaceholderTextIsTreatedAsNoPlaceholder() throws {
    let textView = CLTextView()
    textView.placeholderText = "" // Explicitly empty, not nil.

    let label = try #require(placeholderLabel(in: textView))
    #expect(label.isHidden)
  }

  /// The collapsed-notes case: `ItemContentView` collapses an item's notes field to a 0pt height
  /// constraint, and the placeholder must not show through. It is the text view's clipping that
  /// enforces that — the label is pinned to all four edges, which on a scroll view sets contentSize
  /// rather than the label's frame, so the label keeps its natural height and overflows.
  @Test("a collapsed text view clips its overflowing placeholder")
  func collapsedTextViewClipsItsOverflowingPlaceholder() throws {
    let textView = CLTextView()
    textView.placeholderText = "Notes"
    textView.translatesAutoresizingMaskIntoConstraints = false
    textView.heightAnchor.constraint(equalToConstant: 0.0).isActive = true
    textView.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
    textView.layoutIfNeeded()

    let label = try #require(placeholderLabel(in: textView))
    #expect(label.frame.height > textView.bounds.height, "Precondition: the label overflows.")
    #expect(textView.clipsToBounds, "Without clipping, the placeholder renders outside the collapsed field.")
  }

  @Test("setting font keeps the placeholder label's font in sync")
  func fontOverrideKeepsPlaceholderLabelInSync() throws {
    let textView = CLTextView()
    let font = UIFont.boldSystemFont(ofSize: 21.0)

    textView.font = font

    let label = try #require(placeholderLabel(in: textView))
    #expect(label.font == font)
  }

  @Test("setting font to nil falls back to the default placeholder font")
  func fontOverrideFallsBackWhenSetToNil() throws {
    let textView = CLTextView()

    textView.font = nil

    let label = try #require(placeholderLabel(in: textView))
    #expect(label.font == UIFont.systemFont(ofSize: 8.0))
  }
}
