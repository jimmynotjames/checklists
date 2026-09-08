//
//  CLTextViewTests.swift
//  checklistsTests
//
//  Created by Claude on 8/31/26.
//

@testable import checklists
import XCTest

/// Covers `CLTextView`'s placeholder-visibility rule (`updatePlaceholderLabel`, private, but its
/// effect on the placeholder label's `isHidden` is observable via the view hierarchy) and that the
/// `text`/`font` property overrides keep it in sync.
///
/// No Realm/DBManager involvement, so this doesn't need the in-memory-Realm save/restore pattern
/// the persistence-touching test classes use. See the note on `DataModelTests` for why this class
/// is `nonisolated` at the type level with individual `@MainActor` test methods.
nonisolated final class CLTextViewTests: XCTestCase {
  /// `placeholderLabel` is private; it's the view's only `UILabel` subview, added directly to the
  /// text view itself (`setUpSubviews()`), so it's reachable this way without touching anything
  /// else private.
  private func placeholderLabel(in textView: CLTextView) -> UILabel? {
    textView.subviews.compactMap { $0 as? UILabel }.first
  }

  @MainActor func testPlaceholderHiddenWhenNoPlaceholderTextSet() throws {
    let textView = CLTextView()
    let label = try XCTUnwrap(placeholderLabel(in: textView))
    XCTAssertTrue(label.isHidden)
  }

  @MainActor func testPlaceholderVisibleWhenTextEmptyAndPlaceholderSet() throws {
    let textView = CLTextView()
    textView.placeholderText = "Notes"

    let label = try XCTUnwrap(placeholderLabel(in: textView))
    XCTAssertFalse(label.isHidden)
    XCTAssertEqual(label.text, "Notes")
  }

  @MainActor func testPlaceholderHiddenOnceTextIsSet() throws {
    let textView = CLTextView()
    textView.placeholderText = "Notes"
    let label = try XCTUnwrap(placeholderLabel(in: textView))
    XCTAssertFalse(label.isHidden) // Precondition.

    textView.text = "hello"

    XCTAssertTrue(label.isHidden)
  }

  @MainActor func testPlaceholderReappearsWhenTextClearedAgain() throws {
    let textView = CLTextView()
    textView.placeholderText = "Notes"
    textView.text = "hello"
    let label = try XCTUnwrap(placeholderLabel(in: textView))
    XCTAssertTrue(label.isHidden) // Precondition.

    textView.text = ""

    XCTAssertFalse(label.isHidden)
  }

  @MainActor func testEmptyPlaceholderTextIsTreatedAsNoPlaceholder() throws {
    let textView = CLTextView()
    textView.placeholderText = "" // Explicitly empty, not nil.

    let label = try XCTUnwrap(placeholderLabel(in: textView))
    XCTAssertTrue(label.isHidden)
  }

  /// The collapsed-notes case: `ItemContentView` collapses an item's notes field to a 0pt height
  /// constraint, and the placeholder must not show through. It is the text view's clipping that
  /// enforces that — the label is pinned to all four edges, which on a scroll view sets contentSize
  /// rather than the label's frame, so the label keeps its natural height and overflows.
  @MainActor func testCollapsedTextViewClipsItsOverflowingPlaceholder() throws {
    let textView = CLTextView()
    textView.placeholderText = "Notes"
    textView.translatesAutoresizingMaskIntoConstraints = false
    textView.heightAnchor.constraint(equalToConstant: 0.0).isActive = true
    textView.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
    textView.layoutIfNeeded()

    let label = try XCTUnwrap(placeholderLabel(in: textView))
    XCTAssertGreaterThan(label.frame.height, textView.bounds.height, "Precondition: the label overflows.")
    XCTAssertTrue(textView.clipsToBounds, "Without clipping, the placeholder renders outside the collapsed field.")
  }

  @MainActor func testFontOverrideKeepsPlaceholderLabelInSync() throws {
    let textView = CLTextView()
    let font = UIFont.boldSystemFont(ofSize: 21.0)

    textView.font = font

    let label = try XCTUnwrap(placeholderLabel(in: textView))
    XCTAssertEqual(label.font, font)
  }

  @MainActor func testFontOverrideFallsBackWhenSetToNil() throws {
    let textView = CLTextView()

    textView.font = nil

    let label = try XCTUnwrap(placeholderLabel(in: textView))
    XCTAssertEqual(label.font, UIFont.systemFont(ofSize: 8.0))
  }
}
