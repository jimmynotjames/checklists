//
//  CopyCheckedItemsView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// Destination picker for the checklist detail screen's "Copy Checked Items to…" and "Move Checked
/// Items to…" entries: a New Checklist button, then the checklists already in the list. A move is a
/// copy that then takes the originals out of `source`.
///
/// The copy itself happens here rather than back in `ChecklistViewController`. Picking a
/// destination and writing the items are one decision, and the router's `SheetRoute` carries values
/// rather than callbacks, so splitting them would mean threading a closure through it.
///
/// An existing checklist commits on the tap, dismisses, and leaves the person on the checklist they
/// started from: navigating to the destination would be stronger feedback, but they ticked those
/// items to get here, and yanking them out of a list they are mid-run on loses their place. The
/// toast is what confirms instead.
///
/// New Checklist instead hands over to the create sheet, as Duplicate does: the copies are made
/// first, so the sheet opens on them with the name field focused, and the person names the list,
/// adjusts it, or discards it there. A move removes the originals only once that sheet is closed
/// with the checklist kept (`ModelContext.completeCheckedItemsTransfer`, finished by the source's
/// `ChecklistScreen`), so Discard leaves the source as it was.
struct CopyCheckedItemsView: View {
  let source: Checklist
  let mode: CheckedItemsTransferMode

  /// Display order; id breaks sortKey ties. Keep in step with ModelContext.fetchChecklistsSorted.
  @Query(sort: [SortDescriptor(\Checklist.sortKey), SortDescriptor(\Checklist.id)])
  private var checklists: [Checklist]

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Environment(\.analytics) private var analytics
  @Environment(Router.self) private var router
  /// Optional at the leaf, like `ChecklistScreen`'s rating prompt: previews and tests build this
  /// screen without the app around it, and a missing presenter means "no toast", never a crash.
  @Environment(ToastPresenter.self) private var toasts: ToastPresenter?

  var body: some View {
    NavigationStack {
      Form {
        Group {
          newChecklistSection
          // Omitted rather than shown empty: with only one checklist in the app there is no
          // destination but a new one, and a header over nothing reads as something missing.
          if !destinations.isEmpty {
            existingChecklistsSection
          }
        }
        .formRowBackground()
      }
      .appBackground()
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        // Leading, as a sheet's cancel sits.
        ToolbarItem(placement: .topBarLeading) {
          Button(role: .close) {
            dismiss()
          }
          .tint(Color.accentColor)
        }
      }
      .toastOverlay(.sheet)
    }
  }

  /// Everything but the source. Copying checked items back into the list they came from only
  /// duplicates them in place, which the per-item swipe action already does; moving them there
  /// would only uncheck them.
  private var destinations: [Checklist] {
    checklists.filter { $0.id != source.id }
  }

  // MARK: - Sections

  private var newChecklistSection: some View {
    Section {
      Button(action: openNewChecklist) {
        Label(Self.newChecklistTitle, systemImage: "plus")
          .foregroundStyle(Color.accentColor)
          // Widened so the whole row is the target, as the destination rows below are.
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("copyDestination.newChecklist")
    }
  }

  private var existingChecklistsSection: some View {
    Section {
      ForEach(destinations) { checklist in
        Button {
          copyCheckedItems(into: checklist)
        } label: {
          Text(Self.displayName(of: checklist))
            .foregroundStyle(Colors.primaryTextColor)
            // The label is only as wide as its text, so widen it to make the whole row tappable
            // rather than just the words — as `ChecklistsView`'s rows do.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("copyDestination.\(checklist.id)")
      }
    } header: {
      Text(Self.existingSectionHeader)
        .foregroundStyle(Colors.inactiveTextColor)
    }
  }

  // MARK: - Copying

  /// Whether there is still anything to copy.
  ///
  /// The menu asked this once, when it opened. A merge from another device can Reset the source
  /// while this sheet is up, and without re-asking, committing would put a brand-new empty
  /// checklist at the top of the list, count a `checklist_items_copied` or `checklist_items_moved`,
  /// and say it worked.
  /// Leaving is the honest response: the person's own list is unchanged either way. The toast says
  /// why, since the sheet otherwise just closes on a tap.
  private func hasSomethingToCopy() -> Bool {
    guard source.checkedItems.isEmpty else { return true }
    dismiss()
    // After the dismissal, like `confirmTransfer`, so the screen beneath draws it and its announcement
    // waits for the sheet to go.
    toasts?.show(.noCheckedItemsLeft)
    return false
  }

  /// Copies into a new, unnamed checklist and swaps this sheet for the create sheet on it. Nothing
  /// is tracked or confirmed yet, since Discard may still undo it.
  private func openNewChecklist() {
    guard hasSomethingToCopy() else { return }
    let itemIDs = source.checkedItems.map(\.id)
    let destination: Checklist
    do {
      // Unnamed, as `ChecklistsView.addChecklist`'s is, so the create sheet's name field opens
      // blank on its placeholder.
      destination = try context.copyCheckedItems(of: source, intoChecklistNamed: "", among: Array(checklists))
    } catch {
      return // Already logged and reported by `saveChanges`; nothing was added.
    }
    let transfer = CheckedItemsTransfer(sourceID: source.id, mode: mode, itemIDs: itemIDs)
    // Replacing the route, not dismissing first: this sheet slides away and the create sheet
    // slides up in its place.
    router.sheet = .checkedItemsChecklist(id: destination.id, transfer: transfer)
  }

  private func copyCheckedItems(into destination: Checklist) {
    guard hasSomethingToCopy() else { return }
    do {
      switch mode {
      case .copy:
        try context.copyCheckedItems(of: source, into: destination)
      case .move:
        try context.moveCheckedItems(of: source, into: destination)
      }
    } catch {
      return // Already logged and reported by `saveChanges`; nothing was added, so nothing is tracked.
    }
    dismiss()
    Self.confirmTransfer(mode, into: destination, destination: .existingChecklist, analytics: analytics, toasts: toasts)
  }

  /// Tracks and confirms a finished transfer. Called once the sheet that made it has started
  /// closing, so the screen beneath is the one that draws the toast (see `ToastPresenterModifier`):
  /// here for an existing checklist, and by the source's `ChecklistScreen` for a new one kept on the
  /// create sheet.
  static func confirmTransfer(
    _ mode: CheckedItemsTransferMode,
    into checklist: Checklist,
    destination: CheckedItemsCopyDestination,
    analytics: any AnalyticsClient,
    toasts: ToastPresenter?,
  ) {
    let event = switch mode {
    case .copy: AnalyticsEvent.checklistItemsCopied
    case .move: AnalyticsEvent.checklistItemsMoved
    }
    analytics.track(event, properties: [AnalyticsProperty.destination: destination.rawValue])
    let name = displayName(of: checklist)
    let message = switch mode {
    case .copy: confirmation(forCopyingInto: name)
    case .move: confirmation(forMovingInto: name)
    }
    toasts?.show(Toast(message: message, style: .success))
  }

  /// A checklist saved without a name reads as "untitled checklist" everywhere else.
  private static func displayName(of checklist: Checklist) -> String {
    checklist.name.isEmpty ? CommonStrings.defaultChecklistName : checklist.name
  }

  // MARK: - Copy

  private var title: String {
    switch mode {
    case .copy: Self.copyTitle
    case .move: Self.moveTitle
    }
  }

  private static let copyTitle = String(
    localized: "checklist.copy.title",
    defaultValue: "Copy Checked Items",
    comment: """
    Title of the sheet that asks where to copy the items someone has ticked. The sheet is reached \
    from the checklist detail screen's Copy Checked Items to… menu entry; keep the two consistent.
    """,
  )

  private static let newChecklistTitle = String(
    localized: "checklist.copy.newChecklist",
    defaultValue: "New Checklist",
    comment: """
    Button at the top of the sheet that asks where to copy or move the ticked items. It makes a new \
    checklist holding them and opens it, so the person can name it.
    """,
  )

  private static let existingSectionHeader = String(
    localized: "checklist.copy.existingSection.header",
    defaultValue: "Existing Checklists",
    comment: "Header over the list of checklists the ticked items can be copied or moved into. The checklist they come from is not among them.",
  )

  private static func confirmation(forCopyingInto name: String) -> LocalizedStringResource {
    LocalizedStringResource(
      "checklist.copy.confirmation",
      defaultValue: "Copied items to \(name)",
      comment: """
      Toast shown after the ticked items are copied. The placeholder is the destination \
      checklist's name, which may be a name the person typed or the default untitled one. It \
      appears briefly and is also read aloud by VoiceOver, so keep it to one short line.
      """,
    )
  }

  private static let moveTitle = String(
    localized: "checklist.move.title",
    defaultValue: "Move Checked Items",
    comment: """
    Title of the sheet that asks where to move the items someone has ticked: they are added to the \
    chosen checklist and removed from this one. Reached from the checklist detail screen's Move \
    Checked Items to… menu entry; keep the two consistent, and keep it distinct from \
    checklist.copy.title, which leaves the items where they were.
    """,
  )

  private static func confirmation(forMovingInto name: String) -> LocalizedStringResource {
    LocalizedStringResource(
      "checklist.move.confirmation",
      defaultValue: "Moved items to \(name)",
      comment: """
      Toast shown after the ticked items are moved into another checklist and removed from this \
      one. The placeholder is the destination checklist's name, which may be a name the person \
      typed or the default untitled one. It appears briefly and is also read aloud by VoiceOver, \
      so keep it to one short line.
      """,
    )
  }
}

#if DEBUG
  #Preview("Destination picker") {
    CopyCheckedItemsView(source: PreviewSupport.checklist(), mode: .copy)
      .previewEnvironment()
  }
#endif
