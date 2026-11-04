//
//  CopyCheckedItemsView.swift
//  checklists
//

import SwiftData
import SwiftUI

/// Destination picker for the checklist detail screen's "Copy Checked Items to…" and "Move Checked
/// Items to…" entries: the checklists already in the list, plus a field for naming a new one. A move
/// is a copy that then takes the originals out of `source`.
///
/// The copy itself happens here rather than back in `ChecklistViewController`. Picking a
/// destination, naming a new list and writing the items are one decision, and the router's
/// `SheetRoute` carries values rather than callbacks, so splitting them would mean threading a
/// closure through it.
///
/// Both paths dismiss and leave the person on the checklist they started from. Navigating to the
/// destination would be stronger feedback, but they ticked those items to get here — yanking them
/// out of a list they are mid-run on loses their place. The toast is what confirms instead, and it
/// is why the naming field below is load-bearing rather than a convenience: with no navigation,
/// this sheet is the only chance to name the new list.
struct CopyCheckedItemsView: View {
  let source: Checklist
  let mode: CheckedItemsTransferMode

  /// Display order; id breaks sortKey ties. Keep in step with ModelContext.fetchChecklistsSorted.
  @Query(sort: [SortDescriptor(\Checklist.sortKey), SortDescriptor(\Checklist.id)])
  private var checklists: [Checklist]

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Environment(\.analytics) private var analytics
  /// Optional at the leaf, like `ChecklistScreen`'s rating prompt: previews and tests build this
  /// screen without the app around it, and a missing presenter means "no toast", never a crash.
  @Environment(ToastPresenter.self) private var toasts: ToastPresenter?

  @State private var newChecklistName = ""
  /// Deliberately never set true on appearance. The field is opt-in — most people came for a
  /// destination below it, and a keyboard rising on arrival would cover the list they came for.
  @FocusState private var isNamingFocused: Bool
  /// Where VoiceOver goes once the bar's Done has gone with the keyboard: back to the field just
  /// named, rather than wherever the vanished button leaves it.
  @AccessibilityFocusState private var isNameFieldVoiceOverFocused: Bool

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
        // Leading, as a sheet's cancel sits, so the trailing edge is free for Done while typing.
        ToolbarItem(placement: .topBarLeading) {
          Button(role: .close) {
            dismiss()
          }
          .tint(Color.accentColor)
        }
        // In the bar, as ChecklistScreen has it, not above the keyboard: a keyboard toolbar spans
        // the full width and swallows taps on the destinations behind its clear glass. Ends typing
        // only; the arrow beside the field is what commits.
        if isNamingFocused {
          ToolbarItem(placement: .topBarTrailing) {
            Button(role: .confirm) {
              isNamingFocused = false
              Task {
                // Cleared first, then set a turn later: a focus state still holding its target from
                // an earlier tap would not move VoiceOver when set to the same value.
                isNameFieldVoiceOverFocused = false
                await Task.yield()
                // After the bar has relaid without the button VoiceOver was on.
                try? await Task.sleep(for: .milliseconds(500))
                isNameFieldVoiceOverFocused = true
              }
            }
            .tint(Color.accentColor)
            .accessibilityIdentifier("copyDestination.editingDone")
          }
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
      HStack {
        // The palette's placeholder: iOS's own fails 4.5:1 on the row.
        TextField(
          Self.namePlaceholder,
          text: $newChecklistName,
          prompt: Text(Self.namePlaceholder).foregroundStyle(Colors.placeholderTextColor),
        )
        .focused($isNamingFocused)
        .accessibilityFocused($isNameFieldVoiceOverFocused)
        .submitLabel(.done)
        .onSubmit(createChecklistAndCopy)
        .accessibilityIdentifier("copyDestination.newChecklistName")
        .foregroundStyle(Colors.primaryTextColor)
        // Visible and enabled whether or not anything has been typed: a blank field is a legal
        // choice — it commits under the default name — so someone who never types still needs
        // something to tap. Return commits too.
        Button(action: createChecklistAndCopy) {
          Image(systemName: "arrow.forward.circle.fill")
            .font(.title2)
            .foregroundStyle(Color.accentColor)
            // The symbol alone is about 24pt, and `.plain` scopes hit-testing to the label, so the
            // label carries the 44pt minimum; a near-miss would otherwise raise the keyboard.
            .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
        }
        // Plain, so the hit area doesn't swallow taps meant for the field beside it.
        .buttonStyle(.plain)
        .accessibilityLabel(createAccessibilityLabel)
        .accessibilityIdentifier("copyDestination.createNewChecklist")
      }
    } header: {
      Text(Self.newSectionHeader)
        .foregroundStyle(Colors.inactiveTextColor)
    }
  }

  private var existingChecklistsSection: some View {
    Section {
      ForEach(destinations) { checklist in
        Button {
          copyCheckedItems(into: checklist)
        } label: {
          Text(displayName(of: checklist))
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
    // After the dismissal, like `finish`, so the screen beneath draws it and its announcement
    // waits for the sheet to go.
    toasts?.show(.noCheckedItemsLeft)
    return false
  }

  private func createChecklistAndCopy() {
    guard hasSomethingToCopy() else { return }
    let typed = newChecklistName.trimmingCharacters(in: .whitespacesAndNewlines)
    // An empty field commits under the name an unnamed checklist carries everywhere else, rather
    // than introducing a second untitled string.
    let name = typed.isEmpty ? CommonStrings.defaultChecklistName : typed
    let destination: Checklist
    do {
      destination = switch mode {
      case .copy:
        try context.copyCheckedItems(of: source, intoChecklistNamed: name, among: Array(checklists))
      case .move:
        try context.moveCheckedItems(of: source, intoChecklistNamed: name, among: Array(checklists))
      }
    } catch {
      return // Already logged and reported by `saveChanges`; nothing was added, so nothing is tracked.
    }
    finish(copiedInto: destination, destination: .newChecklist)
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
      return // As above.
    }
    finish(copiedInto: destination, destination: .existingChecklist)
  }

  /// Track, dismiss, then confirm — in that order, so the screen beneath the sheet is the one that
  /// draws the toast (see `ToastPresenterModifier`).
  private func finish(copiedInto checklist: Checklist, destination: CheckedItemsCopyDestination) {
    let event = switch mode {
    case .copy: AnalyticsEvent.checklistItemsCopied
    case .move: AnalyticsEvent.checklistItemsMoved
    }
    analytics.track(event, properties: [AnalyticsProperty.destination: destination.rawValue])
    dismiss()
    let name = displayName(of: checklist)
    let message = switch mode {
    case .copy: Self.confirmation(forCopyingInto: name)
    case .move: Self.confirmation(forMovingInto: name)
    }
    toasts?.show(Toast(message: message, style: .success))
  }

  /// A checklist saved without a name reads as "untitled checklist" everywhere else.
  private func displayName(of checklist: Checklist) -> String {
    checklist.name.isEmpty ? CommonStrings.defaultChecklistName : checklist.name
  }

  // MARK: - Copy

  private var title: String {
    switch mode {
    case .copy: Self.copyTitle
    case .move: Self.moveTitle
    }
  }

  private var createAccessibilityLabel: String {
    switch mode {
    case .copy: Self.copyCreateAccessibilityLabel
    case .move: Self.moveCreateAccessibilityLabel
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

  private static let newSectionHeader = String(
    localized: "checklist.copy.newSection.header",
    defaultValue: "New Checklist",
    comment: "Header over the row that creates a checklist to copy or move the ticked items into. The row holds an optional name field.",
  )

  private static let namePlaceholder = String(
    localized: "checklist.copy.namePlaceholder",
    defaultValue: "Name (optional)",
    comment: """
    Placeholder in the field naming a new checklist to copy or move the ticked items into. Optional is \
    literal: committing it blank is allowed and the checklist is saved under checklist.defaultName.
    """,
  )

  private static let copyCreateAccessibilityLabel = String(
    localized: "checklist.copy.create.accessibilityLabel",
    defaultValue: "Create checklist and copy items",
    comment: "VoiceOver label for the button beside the name field that creates the new checklist and copies the ticked items into it.",
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

  private static let moveCreateAccessibilityLabel = String(
    localized: "checklist.move.create.accessibilityLabel",
    defaultValue: "Create checklist and move items",
    comment: "VoiceOver label for the button beside the name field that creates the new checklist and moves the ticked items into it.",
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
