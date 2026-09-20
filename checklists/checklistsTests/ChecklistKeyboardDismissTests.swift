//
//  ChecklistKeyboardDismissTests.swift
//  checklistsTests
//

@testable import checklists
import SwiftData
import Testing
import UIKit

/// Covers dragging the list down to dismiss the keyboard.
///
/// The dismissal is observed through `endEditingAfterDragDismiss` rather than a real resign: these
/// tests drive `scrollViewDidScroll` directly and never load the view, so there is no first
/// responder to resign.
@Suite("Dismissing the keyboard by dragging the list")
struct ChecklistKeyboardDismissTests {
  /// Records dismissals instead of ending editing on a view that was never loaded.
  private final class SpyViewController: ChecklistViewController {
    var dismissCount = 0

    override func endEditingAfterDragDismiss() {
      dismissCount += 1
    }
  }

  /// Reports a fixed translation. `setTranslation(_:in:)` does not stick on a recognizer that is
  /// not tracking a real touch, so the value has to be stubbed rather than set.
  private final class StubPanGestureRecognizer: UIPanGestureRecognizer {
    var stubbedTranslation: CGPoint = .zero

    override func translation(in _: UIView?) -> CGPoint {
      stubbedTranslation
    }
  }

  /// A scroll view that reports itself as mid-drag, which is otherwise read-only.
  private final class DraggingScrollView: UIScrollView {
    let stubbedPan = StubPanGestureRecognizer()
    var stubbedIsDragging = true

    override var isDragging: Bool {
      stubbedIsDragging
    }

    override var panGestureRecognizer: UIPanGestureRecognizer {
      stubbedPan
    }
  }

  private func makeViewController() throws -> SpyViewController {
    let container = try TestModelContainer.make()
    let context = ModelContext(container)
    let checklist = Checklist()
    context.insert(checklist)
    try context.save()

    let viewController = SpyViewController()
    viewController.checklist = checklist
    viewController.context = context
    return viewController
  }

  private func makeScrollView(draggedBy verticalTranslation: CGFloat, isDragging: Bool = true) -> UIScrollView {
    let scrollView = DraggingScrollView()
    scrollView.stubbedPan.stubbedTranslation = CGPoint(x: 0.0, y: verticalTranslation)
    scrollView.stubbedIsDragging = isDragging
    return scrollView
  }

  @Test("dragging down past the threshold ends editing")
  func draggingDownPastThresholdEndsEditing() throws {
    let viewController = try makeViewController()

    viewController.scrollViewDidScroll(makeScrollView(draggedBy: 60.0))

    #expect(viewController.dismissCount == 1, "A deliberate downward drag should commit the edit.")
  }

  /// The inverse guard: scrolling up to read the rest of the list must not throw away an edit.
  @Test("scrolling up leaves an edit in progress alone")
  func draggingUpLeavesEditingAlone() throws {
    let viewController = try makeViewController()

    viewController.scrollViewDidScroll(makeScrollView(draggedBy: -120.0))

    #expect(viewController.dismissCount == 0, "Scrolling up should leave an edit in progress alone.")
  }

  /// A short drag is a scroll adjustment, not an intent to dismiss.
  @Test("a short downward drag leaves editing alone")
  func shortDownwardDragLeavesEditingAlone() throws {
    let viewController = try makeViewController()

    viewController.scrollViewDidScroll(makeScrollView(draggedBy: 12.0))

    #expect(viewController.dismissCount == 0, "A drag short of the threshold should not dismiss.")
  }

  /// Programmatic scrolling — the keyboard-avoidance code does this — is not a user gesture.
  @Test("programmatic scrolling without dragging leaves editing alone")
  func scrollingWithoutDraggingLeavesEditingAlone() throws {
    let viewController = try makeViewController()

    viewController.scrollViewDidScroll(makeScrollView(draggedBy: 200.0, isDragging: false))

    #expect(viewController.dismissCount == 0, "Programmatic scrolling should not dismiss the keyboard.")
  }
}
