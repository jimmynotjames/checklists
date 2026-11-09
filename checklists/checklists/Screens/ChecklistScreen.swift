//
//  ChecklistScreen.swift
//  checklists
//

import SwiftData
import SwiftUI
import UIKit

/// SwiftUI host for the still-UIKit `ChecklistViewController`: the detail column of `RootView`'s
/// split view, or the root of the create sheet's `NavigationStack`. The controller decides what the bar shows (`ChecklistBar`); this view's
/// toolbar draws it, so the bar is the stack's own and iPhone Duo's vertical bar takes its items as
/// it does on every other screen.
///
/// The wrapper exists so the safe-area handling and the toolbar below travel with the screen
/// instead of being restated at each presentation site.
struct ChecklistScreen: View {
  let checklist: Checklist
  var isNewChecklist = false
  /// Routes the screen's own ways of leaving (Done, Delete or Discard, remote deletion) through the
  /// SwiftUI router so navigation state can't desync from what's on screen; a narrow window's
  /// back button and swipe update the router's selection themselves (`Router.compactColumn`).
  let onRequestDismiss: () -> Void

  @Environment(Router.self) private var router
  @Environment(AnalyticsSettings.self) private var settings
  /// Bumped when a move out of this checklist's items finishes. The picker edits the store while
  /// the controller sits under it, and a sheet's dismissal gives a UIKit screen no appearance
  /// callback to reload on, so this is what tells it.
  @State private var transferGeneration = 0
  @State private var bar = ChecklistBar()
  /// Where VoiceOver goes when the controller asks; see `ChecklistBar.focusRequest`.
  @AccessibilityFocusState private var focusedBarItem: ChecklistBar.Item?

  var body: some View {
    ChecklistControllerView(
      checklist: checklist,
      isNewChecklist: isNewChecklist,
      onRequestDismiss: onRequestDismiss,
      // A duplicate opens in the create sheet, not as a push: like `ChecklistsView.addChecklist`'s
      // row, it exists in the store but has not been kept yet. Everything the sheet does about that
      // is what a copy wants — Done instead of Reset, the name field focused for renaming, no
      // history caption, and Discard as the way to undo an accidental duplicate.
      onRequestOpenDuplicate: { id in router.sheet = .newChecklist(id: id) },
      // The picker does the copying or moving itself and dismisses without navigating, so this and
      // `transferGeneration` are the whole of the host's involvement — see `CopyCheckedItemsView`.
      onRequestTransferCheckedItems: { id, mode in router.sheet = .transferCheckedItems(sourceID: id, mode: mode) },
      transferGeneration: transferGeneration,
      bar: bar,
    )
    // Inline: the scroll handler puts the name in the title, which a large-title bar would grow a
    // row for.
    .navigationTitle(bar.title ?? "")
    .navigationBarTitleDisplayMode(.inline)
    // Reorder Items mode hides Back, and its edge swipe with it. On a narrow window Done is then the
    // one way out; on a wide one, picking another row in ChecklistsView also leaves.
    .navigationBarBackButtonHidden(bar.mode == .reordering)
    // Visible explicitly: in Reorder Items mode the bar holds only its pinned Done, with no title
    // and no Back, and the system otherwise hides it as empty, Done and all.
    .toolbarVisibility(.visible, for: .navigationBar)
    .toolbar { toolbarContent }
    .background { newItemShortcut }
    .onChange(of: bar.focusRequest) { _, request in
      guard let request else { return }
      Task {
        // Cleared first, then set a turn later: a focus state still holding its target would not
        // move VoiceOver when set to the same value.
        focusedBarItem = nil
        await Task.yield()
        focusedBarItem = request.item
      }
    }
    .onChange(of: router.sheet) { oldSheet, newSheet in
      // Matched before `checklist` is read: on the create sheet, Discard clears the sheet after
      // deleting the checklist. A cancelled move counts too: a reload of an unchanged list is
      // invisible.
      guard newSheet == nil, case let .transferCheckedItems(sourceID, .move) = oldSheet,
            sourceID == checklist.id else { return }
      transferGeneration += 1
    }
    // The view controller does its own keyboard avoidance via contentInset; opt out of SwiftUI's so
    // they don't stack.
    .ignoresSafeArea(.keyboard)
    // `.keyboard` narrows the ignored region, not the edges, so the table is still laid out inside
    // the container safe area — leaving the strips above and below it showing the presenting
    // background rather than the table's own `Colors.defaultBackground`. Not a full
    // `ignoresSafeArea()`: giving the table real safe-area insets would shift `scrollViewDidScroll`'s
    // title threshold.
    .background(Colors.defaultBackgroundColor.ignoresSafeArea())
    // First-run consent trigger (`analytics-spec.md §Strict-opt-in jurisdictions`): the moment
    // right before `checklist_name` could first be transmitted. `isNewChecklist` is load-bearing —
    // in the `.newChecklist` route this view *is* the presented sheet, so presenting the consent
    // sheet there would replace the sheet the person is already looking at.
    .task {
      guard !isNewChecklist,
            ConsentJurisdiction.kind(for: Locale.current.region?.identifier) == .required,
            !settings.analyticsOptInExplicitlySet else { return }
      router.sheet = .analyticsConsent
    }
  }

  // MARK: - Toolbar

  @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
    if let pinned = bar.pinnedItem {
      // Its own pill, as Notes draws it, rather than one shared with the menu.
      ToolbarItem(placement: .topBarPinnedTrailing) {
        button(for: pinned)
      }
    }
    // Leading-first here; `trailingItems` lists them outer edge first.
    if bar.trailingItems.contains(.primary) {
      ToolbarItem(placement: .topBarTrailing) {
        button(for: .primary)
      }
      // A pill of its own: a word beside a symbol in one would read as a single control (HIG,
      // Toolbars: "Keep actions with text labels separate").
      ToolbarSpacer(.fixed, placement: .topBarTrailing)
    }
    if bar.trailingItems.contains(.more) {
      ToolbarItem(placement: .topBarTrailing) {
        moreMenu
      }
    }
  }

  @ViewBuilder private func button(for item: ChecklistBar.Item) -> some View {
    switch item {
    case .more:
      moreMenu
    case .primary where bar.isNewChecklist:
      // The create sheet already inserted and saved a real row before this screen appeared
      // (ChecklistsView.addChecklist), so it needs its own way out besides Done: the menu doubles
      // as "cancel creation" here, worded as a discard rather than a delete.
      doneButton(.primary, id: "checklist.done")
    case .primary:
      // Reset keeps the bar slot: in an app built around rerunning a list it is a per-run action,
      // while deleting the list is a once-ever one that can afford to sit a tap deeper. A word, not
      // an icon: no symbol reads as "uncheck every item" at a glance, and the arrows that come
      // closest read as Undo or Refresh. On iPhone Duo that keeps it in a horizontal bar above the
      // vertical one, which is the accepted cost.
      Button(ChecklistViewController.resetButtonTitle) { bar.perform(.primary) }
        .tint(Color.accentColor)
        // Bar text stops growing with the text size; a long press shows it enlarged instead.
        .accessibilityShowsLargeContentViewer()
        .accessibilityIdentifier("checklist.reset")
        .accessibilityFocused($focusedBarItem, equals: .primary)
    case .editingDone:
      // In the bar, not above the keyboard: on iOS 26 a keyboard toolbar spans the full width and
      // swallows taps on the rows behind its clear glass.
      doneButton(.editingDone, id: "checklist.editingDone")
    case .reorderDone:
      doneButton(.reorderDone, id: "checklist.reorderDone")
        .keyboardShortcut(.cancelAction)
    }
  }

  /// ⌘N, as an unseen button titled for the iPad's ⌘ list: no bar button adds an item. Here rather
  /// than among the controller's key commands, which reach it only while a field has the keyboard.
  private var newItemShortcut: some View {
    Button(ChecklistViewController.newItemShortcutTitle) { bar.addItem() }
      .keyboardShortcut(bar.mode == .reordering ? nil : KeyboardShortcut("n"))
      .frame(width: 0, height: 0)
      .opacity(0)
      .accessibilityHidden(true)
  }

  /// The system's own checkmark and "Done" label, as ChecklistsView's Edit mode Done has it. Every
  /// Done on this screen is one of these, pinned at the outer edge.
  private func doneButton(_ item: ChecklistBar.Item, id: String) -> some View {
    Button(role: .confirm) {
      switch item {
      case .editingDone: bar.perform(.editingDone)
      case .reorderDone: bar.perform(.reorderDone)
      case .more, .primary: bar.perform(.primary)
      }
    }
    // `accentFill`: iOS draws a white checkmark on a capsule of this tint.
    .tint(Colors.accentFillColor)
    .accessibilityShowsLargeContentViewer()
    .accessibilityIdentifier(id)
    .accessibilityFocused($focusedBarItem, equals: item)
  }

  private var moreMenu: some View {
    Menu {
      // Rows in the system's own colors: the menu's accent tint would otherwise reach them, and
      // `.destructive` is the only colour this menu carries.
      Group {
        // Dividers, not `Section`s: inside a menu `Section` SwiftUI drops the entries'
        // accessibility identifiers, which the UI tests find them by.
        ForEach(Array(bar.menuSections.enumerated()), id: \.offset) { index, section in
          if index > 0 {
            Divider()
          }
          ForEach(section, id: \.self) { action in
            menuEntry(action)
          }
        }
      }
      .tint(nil)
    } label: {
      // A label rather than a bare image: its title is what VoiceOver reads and what the Large
      // Content Viewer shows.
      Label(CommonStrings.more, systemImage: "ellipsis")
        .accessibilityShowsLargeContentViewer()
    }
    .tint(Color.accentColor)
    // Locale-invariant handle for UI tests; the label above is what VoiceOver reads.
    .accessibilityIdentifier("checklist.more")
    .accessibilityFocused($focusedBarItem, equals: .more)
  }

  private func menuEntry(_ action: ChecklistBar.Action) -> some View {
    let entry = MenuEntry(action, isNewChecklist: bar.isNewChecklist)
    return Button(entry.title, systemImage: entry.systemImage, role: entry.isDestructive ? .destructive : nil) {
      bar.perform(action)
    }
    .accessibilityIdentifier(entry.accessibilityIdentifier ?? "")
  }
}

/// How a ⋯ menu entry reads. Three distinct glyphs for the checked-items entries, none shared with
/// a neighbour: Copy sits under Duplicate's `plus.square.on.square`, and Delete Checked Items over
/// Delete Checklist's `trash`, and a shared glyph would make one read as the other.
private struct MenuEntry {
  let title: String
  let systemImage: String
  var isDestructive = false
  /// Locale-invariant handles for UI tests and the localized screenshot capture.
  var accessibilityIdentifier: String?

  init(_ action: ChecklistBar.Action, isNewChecklist: Bool) {
    typealias Strings = ChecklistViewController
    switch action {
    case .reorderItems:
      self.init(title: Strings.reorderItemsMenuTitle, systemImage: "arrow.up.arrow.down", accessibilityIdentifier: "checklist.menu.reorderItems")
    case .duplicate:
      self.init(title: Strings.duplicateChecklistMenuTitle, systemImage: "plus.square.on.square")
    case .copyCheckedItems:
      self.init(title: Strings.copyCheckedItemsMenuTitle, systemImage: "doc.on.doc", accessibilityIdentifier: "checklist.menu.copyCheckedItems")
    case .moveCheckedItems:
      self.init(title: Strings.moveCheckedItemsMenuTitle, systemImage: "arrow.turn.up.right", accessibilityIdentifier: "checklist.menu.moveCheckedItems")
    case .exportPDF:
      self.init(title: Strings.exportPDFMenuTitle, systemImage: "square.and.arrow.up", accessibilityIdentifier: "checklist.menu.exportPDF")
    case .deleteCheckedItems:
      self.init(title: Strings.deleteCheckedItemsMenuTitle, systemImage: "checkmark.circle.badge.xmark", isDestructive: true, accessibilityIdentifier: "checklist.menu.deleteCheckedItems")
    case .deleteChecklist:
      self.init(title: isNewChecklist ? Strings.discardChecklistMenuTitle : Strings.deleteChecklistMenuTitle, systemImage: "trash", isDestructive: true)
    case .primary, .editingDone, .reorderDone:
      preconditionFailure("Not a menu entry.")
    }
  }

  private init(title: String, systemImage: String, isDestructive: Bool = false, accessibilityIdentifier: String? = nil) {
    self.title = title
    self.systemImage = systemImage
    self.isDestructive = isDestructive
    self.accessibilityIdentifier = accessibilityIdentifier
  }
}

private struct ChecklistControllerView: UIViewControllerRepresentable {
  let checklist: Checklist
  let isNewChecklist: Bool
  let onRequestDismiss: () -> Void
  let onRequestOpenDuplicate: (String) -> Void
  let onRequestTransferCheckedItems: (String, CheckedItemsTransferMode) -> Void
  let transferGeneration: Int
  let bar: ChecklistBar

  @Environment(\.analytics) private var analytics
  /// Named `modelContext` rather than `context`: `makeUIViewController(context:)` already binds
  /// that name.
  @Environment(\.modelContext) private var modelContext
  /// Optional on purpose: previews and tests build this screen without the app around it, and a
  /// missing coordinator should mean "no prompt", never a crash. `ChecklistsApp` always injects it.
  @Environment(RatingPromptCoordinator.self) private var ratingPrompt: RatingPromptCoordinator?
  /// Optional for the same reason as `ratingPrompt`.
  @Environment(ToastPresenter.self) private var toasts: ToastPresenter?

  func makeCoordinator() -> Coordinator {
    Coordinator(transferGeneration: transferGeneration)
  }

  func makeUIViewController(context _: Context) -> ChecklistViewController {
    let viewController = ChecklistViewController()
    viewController.checklist = checklist
    viewController.context = modelContext
    viewController.isNewChecklist = isNewChecklist
    viewController.onRequestDismiss = onRequestDismiss
    viewController.onRequestOpenDuplicate = onRequestOpenDuplicate
    viewController.onRequestTransferCheckedItems = onRequestTransferCheckedItems
    viewController.onPDFExportFailed = { [toasts] in toasts?.show(.pdfExportFailed) }
    viewController.onRemoteDeletion = { [toasts] in toasts?.show(.checklistDeletedElsewhere) }
    viewController.onNoCheckedItems = { [toasts] in toasts?.show(.noCheckedItems) }
    viewController.bar = bar
    viewController.analytics = analytics
    viewController.ratingPrompt = ratingPrompt
    return viewController
  }

  @MainActor
  final class Coordinator {
    /// The last `transferGeneration` the controller was brought up to date with.
    var transferGeneration: Int

    init(transferGeneration: Int) {
      self.transferGeneration = transferGeneration
    }
  }

  /// `checklist` and `context` are set once, before `viewDidLoad`, and never re-applied: the
  /// controller's remote-change observer and any rows it inserted belong to that context, and so
  /// does `checklist`. A new container can only arrive across `ChecklistsApp`'s `.ready`/`.failed`
  /// switch, which rebuilds this view anyway; the assertion is the tripwire if that stops being
  /// true. The analytics client and rating-prompt coordinator are re-applied so a swapped instance
  /// never leaves a screen on the old one.
  func updateUIViewController(_ viewController: ChecklistViewController, context: Context) {
    assert(viewController.context === modelContext, "The screen's context changed under a live controller.")
    viewController.analytics = analytics
    viewController.ratingPrompt = ratingPrompt
    if context.coordinator.transferGeneration != transferGeneration {
      context.coordinator.transferGeneration = transferGeneration
      // The same refresh another device's edit gets, guards and all.
      viewController.handleRemoteChange()
    }
  }
}

#if DEBUG
  // In a stack, for the toolbar. Between them these cover every text element on the screen; step
  // through the canvas's Dynamic Type sizes on each, and use the live preview to edit, enter Reorder
  // Items mode, and scroll the name into the navigation bar.

  #Preview("Existing checklist") {
    NavigationStack {
      ChecklistScreen(checklist: PreviewSupport.checklist()) {}
    }
    .previewEnvironment()
  }

  #Preview("Long name and notes") {
    NavigationStack {
      ChecklistScreen(checklist: PreviewSupport.longContentChecklist()) {}
    }
    .previewEnvironment(container: PreviewSupport.scratchContainer)
  }

  // Blank, so the name and notes placeholders show; no history caption on the create sheet.
  #Preview("New checklist") {
    NavigationStack {
      ChecklistScreen(checklist: PreviewSupport.blankChecklist(), isNewChecklist: true) {}
    }
    .previewEnvironment(container: PreviewSupport.scratchContainer)
  }

#endif
